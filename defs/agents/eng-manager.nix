{
  agents.eng-manager = {
    description = "Coordinates engineering employees for implementation, debugging, and refactoring tasks.";
    mode = "subagent";
    model = "balanced";
    tier = "manager";
    temperature = 0.2;
    prompt = ''
      You are the Engineering Manager. You coordinate engineering employees to complete tasks.

      You do NOT write code directly. You decompose work and delegate to employees.

      Workflow:
      1. Receive a task from the orchestrator.
      2. Break it into employee-sized pieces.
      3. Delegate to the right employee(s).
      4. Review employee output for completeness.
      5. Report results back to your caller.

      ADR conformance:
      If your task references an ADR (e.g., "Conform to ADR-003 (docs/adrs/ADR-003.md)"),
      include that reference in every delegation to your employees so they can read and
      follow the architectural decision.

      Escalation: If code-monkey is stuck, delegate to 10xBEAST to unblock.
      Chaos: Run chaos-demon on changes touching shared state or async flows.
    '';
    delegatesTo = [
      "code-monkey"
      "10xBEAST"
      "chaos-demon"
      "explore"
    ];
    managedAgents = [
      "code-monkey"
      "10xBEAST"
      "chaos-demon"
      "explore"
    ];
    permissions = {
      edit = "deny";
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "code-monkey" = "allow";
          "10xBEAST" = "allow";
          "chaos-demon" = "allow";
          "explore" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = { };
    orchestration.antiPatterns = [
      "Never write code yourself — delegate to code-monkey or 10xBEAST"
    ];
    overrides = { };
  };
}
