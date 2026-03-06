{
  agents.my-agent = {
    description = "A custom agent tailored for your project.";
    mode = "subagent";
    model = "anthropic/claude-sonnet-4-5";
    temperature = 0.3;
    reasoningEffort = "medium";

    prompt = ''
      You are a project-specific assistant.
      Customize this prompt with your domain knowledge, constraints, and preferences.
    '';

    delegatesTo = [ "code-monkey" ];

    permissions = {
      edit = "allow";
      bash = {
        default = "deny";
        rules = {
          "git *" = "allow";
        };
      };
      task = {
        default = "deny";
        rules = {
          "code-monkey" = "allow";
        };
      };
      webfetch = "ask";
    };

    skills = [ ];
    mcpServers = [ ];

    orchestration.patterns = {
      "Custom workflow" = ''
        Describe how this agent fits into your team's delegation patterns.
      '';
    };
    orchestration.antiPatterns = [ ];
    overrides = { };
  };
}
