{
  lib,
  config,
  src ? null,
  pkgs ? null,
}:
let
  agentsMdGenerator = import ./agents-md.nix { inherit lib; };
  shared = import ./shared.nix { inherit lib; };
  preamble = shared.mkHumanPreamble config.human;

  # Derive tool list for tiered agents (orchestrator/manager) based on tier + extraTools.
  # Employees and flat agents derive tools from permissions (not emitted here — pi reads
  # permissions from the frontmatter permission block instead).
  mkTierToolsList =
    agent:
    if agent.tier == "orchestrator" || agent.tier == "manager" then
      [ "subagent" ] ++ agent.extraTools
    else
      null; # null = no tools: line emitted; pi infers from permissions block

  workflowGuide =
    if src != null then
      builtins.unsafeDiscardStringContext (builtins.readFile (src + "/AGENTS.md"))
    else
      "";

  generatorDefaults = {
    fast = "minimax/minimax-m2.7-highspeed";
    balanced = "openai/gpt-5.3-codex";
    powerful = "zai/glm-5.1";
    reasoning = "zai/glm-5.1";
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
    name: agent:
    let
      lines = [
        "name: ${name}"
        "description: ${agent.description}"
        "mode: ${agent.mode}"
        "model: ${resolveModel agent.model}"
        "temperature: ${toString agent.temperature}"
      ]
      ++ lib.optional (agent.reasoningEffort != null) "reasoningEffort: ${agent.reasoningEffort}"
      ++ (
        let
          toolsList = mkTierToolsList agent;
        in
        lib.optional (toolsList != null) "tools: ${lib.concatStringsSep "," toolsList}"
      )
      ++ lib.optional (
        agent.managedAgents != [ ]
      ) "visibleAgents: ${lib.concatStringsSep "," agent.managedAgents}"
      ++ lib.optional (
        agent.maxDelegationDepth != null
      ) "maxDelegationDepth: ${toString agent.maxDelegationDepth}"
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
    name: agent:
    let
      managedSection = shared.mkManagedAgentsSection config.agents agent.managedAgents;
    in
    renderFrontmatter name agent + "\n" + preamble + agent.prompt + "\n" + managedSection
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
      [ "${server.package}/bin/${name}" ] ++ server.args
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
