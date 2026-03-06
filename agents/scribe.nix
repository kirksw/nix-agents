{
  agents.scribe = {
    description = "Converts decisions and rationale into clean, concise handoffs.";
    mode = "subagent";
    model = "anthropic/claude-sonnet-4-5";
    temperature = 0.3;
    reasoningEffort = "low";
    prompt = ''
      You generate concise summaries and rationale docs from context provided by other agents.
      Keep language precise and action-oriented.
    '';
    delegatesTo = [ ];
    permissions = {
      edit = {
        default = "allow";
        rules = {
          "*.md" = "allow";
        };
      };
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "code-monkey" = "allow";
          "the-architect" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [ "skill-creator" ];
    mcpServers = [ ];
    orchestration.patterns = {
      "Finalize handoff" = ''
        Ensure each handoff includes rationale, assumptions, and explicit next step.
      '';
    };
    orchestration.antiPatterns = [ ];
    overrides = { };
  };
}
