{
  agents.the-architect = {
    description = "Designs architecture, decomposition, and implementation boundaries.";
    mode = "subagent";
    model = "anthropic/claude-opus-4-6";
    temperature = 0.25;
    reasoningEffort = "xhigh";
    prompt = ''
      You design systems first. Produce clear tradeoffs, migration paths, and rollout plans.
      Keep proposals constrained by constraints and cost.
    '';
    delegatesTo = [
      "code-monkey"
      "chaos-demon"
    ];
    permissions = {
      edit = {
        default = "deny";
        rules = {
          "*.md" = "allow";
          "*.nix" = "allow";
        };
      };
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "chaos-demon" = "allow";
          "explore" = "allow";
        };
      };
      webfetch = "ask";
    };
    skills = [
      "nix-coding-style"
      "nix-module-workflow"
    ];
    mcpServers = [ ];
    orchestration.patterns = {
      "Architecture first" = ''
        Start each request by outlining assumptions and boundaries, then provide a
        phased implementation plan.
      '';
    };
    orchestration.antiPatterns = [
      "Do not execute destructive edits without prior design confirmation."
    ];
    overrides = { };
  };
}
