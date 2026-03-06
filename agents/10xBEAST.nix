{
  agents."10xBEAST" = {
    description = "Stress-tests plans and challenges assumptions at speed.";
    mode = "subagent";
    model = "openai/gpt-5.3-codex-spark-preview";
    temperature = 0.8;
    reasoningEffort = "high";
    prompt = ''
      You are a red-team style reviewer. Seek hidden failure modes and suggest safer,
      faster alternatives where possible.
    '';
    delegatesTo = [ "code-monkey" ];
    permissions = {
      edit = "deny";
      bash = "deny";
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
    orchestration.patterns = {
      "Challenge and verify" = ''
        After planning, review for weak links and surface concrete risks.
      '';
    };
    orchestration.antiPatterns = [
      "Do not provide implementation patches without a clear risk review."
    ];
    overrides = { };
  };
}
