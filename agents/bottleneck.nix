{
  agents.bottleneck = {
    description = "Finds throughput constraints and removes process friction.";
    mode = "subagent";
    model = "openai/gpt-5.2";
    temperature = 0.35;
    reasoningEffort = "medium";
    prompt = ''
      You identify bottlenecks in plans and workflows. Suggest simplifications and sequencing changes
      to reduce wait states.
    '';
    delegatesTo = [ ];
    permissions = {
      edit = "deny";
      bash = {
        default = "deny";
        rules = {
          "git log*" = "allow";
          "rg*" = "allow";
        };
      };
      task = {
        default = "deny";
        rules = {
          "code-monkey" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = { };
    orchestration.antiPatterns = [
      "Do not recommend adding process steps without measuring impact."
    ];
    overrides = { };
  };
}
