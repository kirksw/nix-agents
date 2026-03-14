{
  lib,
  config,
  src ? null,
}:
let
  agentsMdGenerator = import ./agents-md.nix { inherit lib; };

  tierModels = {
    fast = "gpt-4.1-mini";
    balanced = "gpt-4.1";
    powerful = "gpt-4.1";
    reasoning = "o3";
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

  permissionSummary =
    permission:
    let
      normalized = normalizePermission permission;
      entries = lib.mapAttrsToList (pattern: value: "${pattern}=${value}") normalized.rules;
      defaults = "default=${normalized.default}";
    in
    [ defaults ] ++ entries;

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
      };
      permissions = {
        edit = permissionSummary agent.permissions.edit;
        bash = permissionSummary agent.permissions.bash;
        task = permissionSummary agent.permissions.task;
        webfetch = [ "default=${agent.permissions.webfetch}" ];
      };
    in
    builtins.toJSON (body // { inherit permissions; });

  agentsOutput = lib.mapAttrs (
    name: agent: renderFrontmatter name agent + "\n" + agent.prompt + "\n"
  ) config.agents;

  skills = lib.mapAttrs (
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

  mcpEntries = lib.mapAttrsToList (
    name: server:
    if server.type == "remote" then
      {
        type = "remote";
        inherit (server) url;
      }
    else
      {
        type = "local";
        command = resolveCommand name server;
      }
  ) enabledServers;

in
{
  agents = agentsOutput;
  inherit skills;
  agentsMd = agentsMdGenerator { inherit (config) agents; };
  mcpJson = builtins.toJSON mcpEntries;
}
