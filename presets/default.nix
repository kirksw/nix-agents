{ ... }:
{
  imports = [
    ../agents/code-monkey.nix
    ../agents/the-architect.nix
    ../agents/10xBEAST.nix
    ../agents/bottleneck.nix
    ../agents/chaos-demon.nix
    ../agents/code-red.nix
    ../agents/scribe.nix
    ../agents/explore.nix
    ../skills/swe-pruner-mcp.nix
    ../skills/nix-coding-style.nix
    ../skills/nix-flake-ops.nix
    ../skills/nix-module-workflow.nix
    ../skills/skill-creator.nix
    ../mcp-servers/swe-pruner.nix
  ];
}
