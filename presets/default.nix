{ ... }:
{
  imports = [
    ../defs/agents/code-monkey.nix
    ../defs/agents/the-architect.nix
    ../defs/agents/10xBEAST.nix
    ../defs/agents/bottleneck.nix
    ../defs/agents/chaos-demon.nix
    ../defs/agents/code-red.nix
    ../defs/agents/scribe.nix
    ../defs/agents/explore.nix
    ../defs/skills/swe-pruner-mcp.nix
    ../defs/skills/nix-coding-style.nix
    ../defs/skills/nix-flake-ops.nix
    ../defs/skills/nix-module-workflow.nix
    ../defs/skills/secrets-management.nix
    ../defs/skills/skill-creator.nix
    ../defs/skills/session-resume.nix
    ../defs/mcps/swe-pruner.nix
    # NOTE: session-write hooks require pkgs and must be wired in flake.nix:
    #   modules = defaultModules ++ [ (import ./defs/hooks/session-write.nix { inherit pkgs; }) ];
  ];
}
