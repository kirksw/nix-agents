{
  lib,
  config,
  src ? null,
}:
let
  agentsMdGenerator = import ./agents-md.nix { inherit lib; };
  shared = import ./shared.nix { inherit lib; };
  preamble = shared.mkHumanPreamble config.human;

  workflowGuide = if src != null then builtins.readFile "${src}/AGENTS.md" else "";

  generatorDefaults = {
    fast = "anthropic/claude-haiku-4-5-20251001";
    balanced = "anthropic/claude-sonnet-4-6";
    powerful = "google/gemini-2.5-pro";
    reasoning = "anthropic/claude-opus-4-6";
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

  renderPermField =
    depth: name: value:
    let
      normalized = normalizePermission value;
      pad = lib.concatStrings (lib.genList (_: " ") depth);
      innerPad = pad + "  ";
    in
    if normalized.rules == { } then
      "${pad}${name}: ${normalized.default}"
    else
      lib.concatStringsSep "\n" (
        [
          "${pad}${name}:"
          ''${innerPad}"*": ${normalized.default}''
        ]
        ++ lib.mapAttrsToList (pattern: perm: ''${innerPad}"${pattern}": ${perm}'') normalized.rules
      );

  renderFrontmatter =
    agent:
    let
      lines = [
        "description: ${agent.description}"
        "mode: ${agent.mode}"
        "model: ${resolveModel agent.model}"
        "temperature: ${toString agent.temperature}"
      ]
      ++ lib.optional (agent.reasoningEffort != null) "reasoningEffort: ${agent.reasoningEffort}"
      ++ [ "permission:" ]
      ++ [
        (renderPermField 2 "edit" (resolvePermField "edit" agent.permissions.edit))
        (renderPermField 2 "bash" (resolvePermField "bash" agent.permissions.bash))
        (renderPermField 2 "task" (resolvePermField "task" agent.permissions.task))
        (renderPermField 2 "webfetch" (resolvePermField "webfetch" agent.permissions.webfetch))
      ]
      ++ lib.mapAttrsToList (k: v: "${k}: ${builtins.toJSON v}") agent.overrides.opencode;
    in
    "---\n${lib.concatStringsSep "\n" lines}\n---";

  agentsOutput = lib.mapAttrs (
    name: agent: (renderFrontmatter agent) + "\n" + preamble + agent.prompt + "\n"
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
        type = "remote";
        inherit (server) url headers enabled;
      }
    else
      {
        type = "local";
        command = resolveCommand name server;
        inherit (server) environment enabled;
      }
  ) enabledServers;

  opencodeConfig = builtins.toJSON { mcp = mcpEntries; };
in
{
  agents = agentsOutput;
  skills = skillSkel;
  agentsMd =
    if workflowGuide != "" then workflowGuide else agentsMdGenerator { inherit (config) agents; };
  agentListMd = agentsMdGenerator { inherit (config) agents; };
  opencodeJson = opencodeConfig;
}
