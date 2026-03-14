{
  lib,
  config,
  src ? null,
}:
let
  agentsMdGenerator = import ./agents-md.nix { inherit lib; };

  tierModels = {
    fast = "claude-haiku-4-5-20251001";
    balanced = "claude-sonnet-4-6";
    powerful = "claude-sonnet-4-6";
    reasoning = "claude-opus-4-6";
  };
  resolveModel = m: tierModels.${m} or m;

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
    permission: prefix:
    let
      buckets = bucketPermissions permission;
      toRule = prefix: entries: map (entry: "${prefix}:${entry}") entries;
    in
    {
      allow = toRule prefix buckets.allow;
      deny = toRule prefix buckets.deny;
      ask = toRule prefix buckets.ask;
    };

  renderPermissionArrays =
    agent:
    let
      edit = formatPermission agent.permissions.edit "Edit";
      bash = formatPermission agent.permissions.bash "Bash";
      task = formatPermission agent.permissions.task "Task";
      webfetch = {
        allow = if agent.permissions.webfetch == "allow" then [ "Webfetch:*" ] else [ ];
        deny = if agent.permissions.webfetch == "deny" then [ "Webfetch:*" ] else [ ];
        ask = if agent.permissions.webfetch == "ask" then [ "Webfetch:*" ] else [ ];
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
    name: agent: renderFrontmatter name agent + "\n" + agent.prompt + "\n"
  ) config.agents;

  skillSkel = lib.mapAttrs (
    name: skill:
    if skill.src == null then skill.content else "See skill source path in generated directory."
  ) config.skills;

  resolveCommand =
    name: server:
    if server.command != [ ] then
      server.command
    else if server.package != null then
      [ "${server.package}/bin/${name}" ]
    else
      [ ];

  enabledServers = lib.filterAttrs (
    name: server: server.type == "remote" || (resolveCommand name server) != [ ]
  ) config.mcpServers;

  mcpEntries = lib.mapAttrs (
    name: server:
    if server.type == "remote" then
      {
        type = "url";
        inherit (server) url;
        inherit (server) headers;
      }
    else
      {
        command = resolveCommand name server;
        env = server.environment;
      }
  ) enabledServers;

  settings = {
    permissions =
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
  };
in
{
  agents = agentsOutput;
  skills = skillSkel;
  agentsMd = agentsMdGenerator { inherit (config) agents; };
  mcpJson = builtins.toJSON { mcpServers = mcpEntries; };
  settingsJson = builtins.toJSON settings;
  claudeMd = agentsMdGenerator { inherit (config) agents; };
}
