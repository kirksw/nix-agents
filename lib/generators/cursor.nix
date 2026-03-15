# EXPERIMENTAL: Cursor rules generator
# Produces .cursor/rules/*.mdc files and .cursor/mcp.json
{
  lib,
  config,
  src ? null,
  pkgs ? null,
}:
let
  shared = import ./shared.nix { inherit lib; };
  preamble = shared.mkHumanPreamble config.human;

  renderMdc =
    description: body:
    let
      # Quote the description in YAML to safely handle colons, special chars.
      escaped = lib.strings.escape [ "\"" "\\" "\n" ] description;
    in
    ''
      ---
      description: "${escaped}"
      globs:
      alwaysApply: true
      ---
      ${body}
    '';

  agentRules = lib.mapAttrs (
    name: agent: renderMdc agent.description (preamble + agent.prompt)
  ) config.agents;

  skillRules = lib.mapAttrs (name: skill: renderMdc skill.description skill.content) config.skills;

  resolveCommand =
    name: server:
    if server.command != [ ] then
      server.command
    else if server.package != null then
      [ "${server.package}/bin/${name}" ]
    else
      [ ];

  enabledServers = lib.filterAttrs (
    name: server: server.type == "remote" || resolveCommand name server != [ ]
  ) config.mcpServers;

  mcpEntries = lib.mapAttrs (
    name: server:
    if server.type == "remote" then
      { inherit (server) url; }
    else
      { command = resolveCommand name server; }
  ) enabledServers;
in
{
  inherit agentRules skillRules;
  mcpJson = builtins.toJSON { mcpServers = mcpEntries; };
}
