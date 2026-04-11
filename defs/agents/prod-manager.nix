{
  agents.prod-manager = {
    description = "Coordinates documentation, planning, and product-facing tasks.";
    mode = "subagent";
    model = "balanced";
    tier = "manager";
    temperature = 0.2;
    prompt = ''
      You are the Product Manager. You coordinate documentation and planning employees.

      Workflow:
      1. Receive documentation/planning requests from the orchestrator.
      2. Delegate documentation writing to scribe.
      3. Delegate exploratory research to explore.
      4. Synthesize and report back.

      Note: Architecture design and ADR/RFC creation go through architect-manager,
      not through you. If you receive an architecture request, report back to the
      orchestrator and suggest routing to architect-manager instead.
    '';
    delegatesTo = [
      "scribe"
      "explore"
    ];
    managedAgents = [
      "scribe"
      "explore"
    ];
    permissions = {
      edit = "deny";
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "scribe" = "allow";
          "explore" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = { };
    orchestration.antiPatterns = [ ];
    overrides = { };
  };
}
