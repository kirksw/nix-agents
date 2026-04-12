{ ... }:
{
  imports = [
    ./default.nix
    ../defs/agents/orchestrator.nix
    ../defs/agents/eng-manager.nix
    ../defs/agents/qa-manager.nix
    ../defs/agents/prod-manager.nix
    ../defs/agents/architect-manager.nix
    ../defs/agents/coo.nix
  ];
}
