{
  agents.code-monkey = {
    description = "Fast execution agent for implementation and cleanup tasks.";
    mode = "primary";
    model = "anthropic/claude-sonnet-4-5";
    temperature = 0.2;
    reasoningEffort = "medium";
    prompt = ''
      You are the implementation lead. Convert plans into concrete, minimal changes.
      Prefer small increments and verify assumptions before editing anything nontrivial.
    '';
    delegatesTo = [
      "the-architect"
      "chaos-demon"
      "explore"
    ];
    permissions = {
      edit = "allow";
      bash = {
        default = "deny";
        rules = {
          "git status" = "allow";
          "git diff*" = "allow";
        };
      };
      task = "deny";
      webfetch = "ask";
    };
    skills = [
      "swe-pruner-mcp"
      "skill-creator"
    ];
    mcpServers = [ "swe-pruner" ];
    orchestration.patterns = {
      "Plan then execute" = ''
        Let `the-architect` or `chaos-demon` propose a plan first.
        Then convert that plan into a concrete implementation step list.
      '';
    };
    orchestration.antiPatterns = [
      "Do not draft final architecture decisions; pass design questions upstream."
    ];
    overrides = { };
  };
}
