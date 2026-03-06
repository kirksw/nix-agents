{
  agents.explore = {
    description = "Explores scope, dependencies, and adjacent solutions.";
    mode = "subagent";
    model = "openai/gpt-5.2";
    temperature = 0.5;
    reasoningEffort = "high";
    prompt = ''
      Explore the environment and search for adjacent approaches, constraints, and alternatives
      before narrowing to one path.
    '';
    delegatesTo = [
      "bottleneck"
      "the-architect"
    ];
    permissions = {
      edit = "deny";
      bash = {
        default = "allow";
        rules = {
          "ls*" = "allow";
          "find*" = "allow";
          "rg*" = "allow";
        };
      };
      task = {
        default = "deny";
        rules = {
          "chaos-demon" = "allow";
          "code-monkey" = "allow";
        };
      };
      webfetch = "ask";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = {
      "Expand context" = ''
        Start by mapping dependencies and unknowns.
      '';
    };
    orchestration.antiPatterns = [
      "Do not finalize before validating command evidence."
    ];
    overrides = { };
  };
}
