{
  lib,
  config,
  pkgs ? null,
  src ? null,
  ...
}:
let
  agentsMdGenerator = import ./agents-md.nix { inherit lib; };
  shared = import ./shared.nix { inherit lib; };

  workflowGuide =
    if src != null then
      builtins.unsafeDiscardStringContext (builtins.readFile (src + "/AGENTS.md"))
    else
      "";
  preamble = shared.mkHumanPreamble config.human;

  generatorDefaults = {
    fast = "claude-haiku-4-5-20251001";
    balanced = "claude-sonnet-4-6";
    powerful = "claude-sonnet-4-6";
    reasoning = "claude-opus-4-6";
  };
  tierModels = generatorDefaults // config.tierMapping;
  resolveModel = m: tierModels.${m} or m;

  defaults = config.defaultPermissions;
  resolvePermField = field: agentPerm: if agentPerm != null then agentPerm else defaults.${field};

  normalizePermission =
    permission:
    if builtins.isString permission then
      {
        default = permission;
        rules = { };
      }
    else
      permission;

  bucketPermissions =
    permission:
    let
      normalized = normalizePermission permission;
      start = {
        allow = [ ];
        deny = [ ];
        ask = [ ];
      };
      withDefaults =
        if normalized.default == "allow" then
          start // { allow = [ "*" ]; }
        else if normalized.default == "deny" then
          start // { deny = [ "*" ]; }
        else
          start // { ask = [ "*" ]; };
      withRules = lib.foldl' (
        acc: pattern:
        let
          level = normalized.rules.${pattern};
          updated = acc.${level} ++ [ pattern ];
        in
        acc // { ${level} = updated; }
      ) withDefaults (builtins.attrNames normalized.rules);
    in
    withRules;

  formatPermission =
    permission: tool:
    let
      buckets = bucketPermissions permission;
      toRule = entries: map (entry: if entry == "*" then tool else "${tool}(${entry})") entries;
    in
    {
      allow = toRule buckets.allow;
      deny = toRule buckets.deny;
      ask = toRule buckets.ask;
    };

  renderPermissionArrays =
    agent:
    let
      editPerm = resolvePermField "edit" agent.permissions.edit;
      bashPerm = resolvePermField "bash" agent.permissions.bash;
      taskPerm = resolvePermField "task" agent.permissions.task;
      webfetchPerm = resolvePermField "webfetch" agent.permissions.webfetch;
      edit = formatPermission editPerm "Edit";
      bash = formatPermission bashPerm "Bash";
      task = formatPermission taskPerm "Task";
      webfetch = {
        allow = if webfetchPerm == "allow" then [ "WebFetch" ] else [ ];
        deny = if webfetchPerm == "deny" then [ "WebFetch" ] else [ ];
        ask = if webfetchPerm == "ask" then [ "WebFetch" ] else [ ];
      };
    in
    {
      inherit edit;
      inherit bash;
      inherit task;
      inherit webfetch;
    };

  renderFrontmatter =
    name: agent:
    let
      body = {
        inherit name;
        inherit (agent) description;
        model = resolveModel agent.model;
        inherit (agent) mode;
        inherit (agent) delegatesTo;
        inherit (agent) temperature;
        inherit (agent) reasoningEffort;
        permissions = renderPermissionArrays agent;
      };
    in
    "---\n${builtins.toJSON body}\n---\n";

  agentsOutput = lib.mapAttrs (
    name: agent: renderFrontmatter name agent + "\n" + preamble + agent.prompt + "\n"
  ) config.agents;

  skillSkel = lib.mapAttrs (
    _name: skill:
    if skill.src == null then skill.content else "See skill source path in generated directory."
  ) config.skills;

  resolveCommand =
    name: server:
    if server.command != [ ] then
      server.command
    else if server.package != null then
      [ "${server.package}/bin/${name}" ] ++ server.args
    else
      [ ];

  enabledServers = lib.filterAttrs (
    name: server: server.type == "remote" || (resolveCommand name server) != [ ]
  ) config.mcpServers;

  renderLocalMcp = command: {
    type = "stdio";
    command = builtins.head command;
    args = lib.tail command;
    env = { };
  };

  mcpEntries = lib.mapAttrs (
    name: server:
    if server.type == "remote" then
      {
        type = if server.transport != null then server.transport else "http";
        inherit (server) url;
        inherit (server) headers;
      }
    else
      (renderLocalMcp (resolveCommand name server))
      // {
        env = server.environment;
      }
  ) enabledServers;

  # Map nix-agents hook events to Claude Code hook points.
  # session-start, skill-invoked, error have no native Claude Code equivalent — skipped.
  renderClaudeHooks =
    hooks: p:
    let
      makeHookScript =
        hook:
        p.writeShellScript "nix-agents-hook-${hook.event}" (
          (lib.optionalString (hook.package != null) ''
            export PATH="${hook.package}/bin:$PATH"
          '')
          + hook.command
        );

      hooksForEvent =
        event:
        let
          matching = builtins.filter (h: h.event == event) hooks;
        in
        if matching == [ ] then
          [ ]
        else
          [
            {
              matcher = "";
              hooks = map (h: {
                type = "command";
                command = "${makeHookScript h}";
              }) matching;
            }
          ];
    in
    {
      Stop = hooksForEvent "session-end";
      SubagentStop = hooksForEvent "session-end";
      PostToolUse = (hooksForEvent "delegation") ++ (hooksForEvent "commit");
      Notification = hooksForEvent "human-decision";
    };

  permissionsValue =
    lib.foldl'
      (
        acc: name:
        let
          permissions = renderPermissionArrays config.agents.${name};
          merge = {
            allow =
              acc.allow
              ++ permissions.edit.allow
              ++ permissions.bash.allow
              ++ permissions.task.allow
              ++ permissions.webfetch.allow;
            deny =
              acc.deny
              ++ permissions.edit.deny
              ++ permissions.bash.deny
              ++ permissions.task.deny
              ++ permissions.webfetch.deny;
            ask =
              acc.ask
              ++ permissions.edit.ask
              ++ permissions.bash.ask
              ++ permissions.task.ask
              ++ permissions.webfetch.ask;
          };
        in
        merge
      )
      {
        allow = [ ];
        deny = [ ];
        ask = [ ];
      }
      (builtins.attrNames config.agents);

  settings = {
    permissions = permissionsValue;
  }
  // (
    if pkgs != null && config.hooks != [ ] then
      { hooks = renderClaudeHooks config.hooks pkgs; }
    else
      { }
  );
in
{
  agents = agentsOutput;
  skills = skillSkel;
  agentsMd = agentsMdGenerator { inherit (config) agents; };
  mcpJson = builtins.toJSON { mcpServers = mcpEntries; };
  settingsJson = builtins.toJSON settings;
  claudeMd =
    if workflowGuide != "" then
      workflowGuide + "\n\n" + agentsMdGenerator { inherit (config) agents; }
    else
      agentsMdGenerator { inherit (config) agents; };
}
