# EXPERIMENTAL: Amp Code generator
# Produces amp.json and AGENTS.md
{
  lib,
  config,
  src ? null,
  pkgs ? null,
}:
let
  shared = import ./shared.nix { inherit lib; };
  preamble = shared.mkHumanPreamble config.human;
  agentsMdGen = import ./agents-md.nix { inherit lib; };

  agentSections = lib.concatStringsSep "\n\n" (
    lib.mapAttrsToList (
      name: agent: "## Agent: ${name}\n\n${agent.description}\n\n${preamble}${agent.prompt}"
    ) config.agents
  );

  skillSections = lib.concatStringsSep "\n\n" (
    lib.mapAttrsToList (
      name: skill: "## Skill: ${name}\n\n${skill.description}\n\n${skill.content}"
    ) config.skills
  );

  systemPrompt = ''
    # Agent Team

    ${agentSections}

    # Skills

    ${skillSections}
  '';

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

  mcpList = lib.mapAttrsToList (
    name: server:
    if server.type == "remote" then
      {
        inherit name;
        inherit (server) url;
      }
    else
      {
        inherit name;
        command = resolveCommand name server;
      }
  ) enabledServers;

  ampConfig = {
    inherit systemPrompt;
    mcpServers = mcpList;
  };
in
{
  ampJson = builtins.toJSON ampConfig;
  agentsMd = agentsMdGen { inherit (config) agents; };
}
