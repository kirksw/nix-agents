{
  agents.qa-manager = {
    description = "Coordinates quality assurance — code review, chaos testing, and security checks.";
    mode = "subagent";
    model = "balanced";
    tier = "manager";
    temperature = 0.2;
    prompt = ''
      You are the QA Manager. You coordinate quality employees.

      Workflow:
      1. Receive review/test requests from the orchestrator.
      2. Delegate code review to bottleneck.
      3. Delegate chaos/resilience checks to chaos-demon.
      4. Delegate security reviews to code-red.
      5. Synthesize findings and report back.

      ADR conformance checking:
      If your task references an ADR, instruct bottleneck to read the ADR and
      validate that the implementation conforms to it. Report any violations
      with specific file/line references.

      If issues are found, report them clearly with severity. Do not fix them yourself.
    '';
    delegatesTo = [
      "bottleneck"
      "chaos-demon"
      "code-red"
    ];
    managedAgents = [
      "bottleneck"
      "chaos-demon"
      "code-red"
    ];
    permissions = {
      edit = "deny";
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "bottleneck" = "allow";
          "chaos-demon" = "allow";
          "code-red" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = { };
    orchestration.antiPatterns = [
      "Never approve changes without at least one review pass"
    ];
    overrides = { };
  };
}
