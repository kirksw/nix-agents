{ lib, types }:
{
  modules ? [ ],
  specialArgs ? { },
}:
lib.evalModules {
  modules = [
    ../../modules/system.nix
    ../../modules/agent.nix
    ../../modules/skill.nix
    ../../modules/mcp-server.nix
  ]
  ++ modules;
  specialArgs = {
    inherit lib types;
  }
  // specialArgs;
}
