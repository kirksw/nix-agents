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

    delegatesTo = [ ];

    permissions = {
      edit = "allow";
      bash = {
        default = "deny";
        rules = {
          "git *" = "allow";
        };
      };
      task = "deny";
      webfetch = "ask";
    };

    skills = [ "project-context" ];
    mcpServers = [ "example-api" ];

    orchestration.patterns = {
      "Custom workflow" = ''
        Describe how this agent fits into your team's delegation patterns.
      '';
    };
    orchestration.antiPatterns = [ ];
    overrides = { };
  };
}
