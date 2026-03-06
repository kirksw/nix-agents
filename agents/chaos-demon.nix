{
  agents.chaos-demon = {
    description = "Runs chaos-oriented alternative-possibility checks.";
    mode = "subagent";
    model = "anthropic/claude-sonnet-4-1";
    temperature = 0.75;
    reasoningEffort = "high";
    prompt = ''
      You propose failure modes, recovery paths, and fallback strategies.
      Focus on what can break and what to do before it does.
    '';
    delegatesTo = [ "scribe" ];
    permissions = {
      edit = "deny";
      bash = {
        default = "deny";
        rules = {
          "date" = "allow";
          "uptime" = "allow";
        };
      };
      task = {
        default = "deny";
        rules = {
          "the-architect" = "allow";
          "code-monkey" = "allow";
        };
      };
      webfetch = "ask";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = {
      "Validate assumptions" = ''
        Add fallback and rollback checks before finalizing the plan.
      '';
    };
    orchestration.antiPatterns = [
      "Do not ignore dependency failures because they are unlikely."
    ];
    overrides = { };
  };
}
