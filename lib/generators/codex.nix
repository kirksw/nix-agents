# Codex generator — produces per-agent markdown, AGENTS.md, and Codex config fragments.
# MCP server config and permission handling are minimal compared to OpenCode/Claude generators.
{
  lib,
  config,
  ...
}:
let
  agentsMdGenerator = import ./agents-md.nix { inherit lib; };
  shared = import ./shared.nix { inherit lib; };
  preamble = shared.mkHumanPreamble config.human;

  generatorDefaults = {
    fast = "o4-mini";
    balanced = "gpt-4.1";
    powerful = "gpt-4.1";
    reasoning = "o3";
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

  permissionSummary =
    permission:
    let
      normalized = normalizePermission permission;
      entries = lib.mapAttrsToList (pattern: value: "${pattern}=${value}") normalized.rules;
      defaultEntry = "default=${normalized.default}";
    in
    [ defaultEntry ] ++ entries;

  renderFrontmatter =
    name: agent:
    let
      body = {
        inherit name;
        inherit (agent) description;
        inherit (agent) mode;
        model = resolveModel agent.model;
        inherit (agent) delegatesTo;
        inherit (agent) temperature;
      }
      # reasoningEffort is meaningful for o3 and o4-mini; omit when null.
      // lib.optionalAttrs (agent.reasoningEffort != null) {
        inherit (agent) reasoningEffort;
      };
      permissions = {
        edit = permissionSummary (resolvePermField "edit" agent.permissions.edit);
        bash = permissionSummary (resolvePermField "bash" agent.permissions.bash);
        task = permissionSummary (resolvePermField "task" agent.permissions.task);
        webfetch = [ "default=${resolvePermField "webfetch" agent.permissions.webfetch}" ];
      };
    in
    builtins.toJSON (body // { inherit permissions; });

  agentsOutput = lib.mapAttrs (
    name: agent: renderFrontmatter name agent + "\n" + preamble + agent.prompt + "\n"
  ) config.agents;

  skills = lib.mapAttrs (
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

  tomlString = builtins.toJSON;

  tomlStringList = values: "[${lib.concatMapStringsSep ", " tomlString values}]";

  renderMcpToml =
    name: server:
    let
      command = resolveCommand name server;
      commandHead = if command == [ ] then null else builtins.head command;
      commandArgs = if command == [ ] then [ ] else builtins.tail command;
      envToml = lib.optionalString (server.environment != { }) (
        "\n[mcp_servers.${name}.env]\n"
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (envName: value: "${envName} = ${tomlString value}") server.environment
        )
        + "\n"
      );
    in
    lib.optionalString server.enabled (
      if server.type == "remote" then
        ''
          [mcp_servers.${name}]
          url = ${tomlString server.url}
        ''
        + envToml
      else
        ''
          [mcp_servers.${name}]
          command = ${tomlString commandHead}
          args = ${tomlStringList commandArgs}
        ''
        + envToml
    );

  mcpToml = lib.concatStringsSep "\n" (lib.mapAttrsToList renderMcpToml enabledServers);

in
{
  agents = agentsOutput;
  inherit skills;
  agentsMd = agentsMdGenerator { inherit (config) agents; };
  inherit mcpToml;
}
