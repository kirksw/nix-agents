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
    ../defs/skills/nix-agents
    ../defs/skills/system-context
    ../defs/skills/secrets-management.nix
    ../defs/skills/skill-creator
    ../defs/skills/session-resume.nix
    ../defs/skills/add-module
    ../defs/skills/parallel-reviews
    ../defs/mcps/agent-observe.nix
    ../defs/mcps/swe-pruner.nix
    # NOTE: session-write hooks require pkgs and must be wired in flake.nix:
    #   modules = defaultModules ++ [ (import ./defs/hooks/session-write.nix { inherit pkgs; }) ];
  ];
}
