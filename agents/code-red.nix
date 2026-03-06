{
  agents.code-red = {
    description = "Rapid triage specialist for urgent implementation tasks.";
    mode = "subagent";
    model = "openai/gpt-5.2";
    temperature = 0.2;
    reasoningEffort = "medium";
    prompt = ''
      You act during urgent cycles. Triage quickly, propose the minimal safe fix,
      and include rollback instructions.
    '';
    delegatesTo = [ "code-monkey" ];
    permissions = {
      edit = {
        default = "deny";
        rules = {
          "*.md" = "allow";
          "*.nix" = "allow";
        };
      };
      bash = {
        default = "deny";
        rules = {
          "git diff*" = "allow";
          "git show*" = "allow";
        };
      };
      task = {
        default = "deny";
        rules = {
          "the-architect" = "allow";
        };
      };
      webfetch = "ask";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = { };
    orchestration.antiPatterns = [
      "Do not make large refactors under urgent pressure."
    ];
    overrides = { };
  };
}
