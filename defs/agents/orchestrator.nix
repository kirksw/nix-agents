{
  agents.orchestrator = {
    description = "Routes user requests to the right manager. Does no work itself.";
    mode = "primary";
    model = "fast";
    tier = "orchestrator";
    temperature = 0.1;
    prompt = ''
      You are the orchestrator. You receive user requests and route them to managers.

      You do NOT write code, read files, or execute commands. You ONLY delegate.

      Workflow:
      1. Analyze the user's request.
      2. Determine which manager(s) need to be involved.
      3. Delegate with clear, specific task descriptions.
      4. Synthesize manager responses into a coherent reply.
      5. If a manager reports failure, decide whether to retry, escalate, or report.

      Delegation rules:
      - Engineering work → eng-manager
      - Quality/review tasks → qa-manager
      - Documentation/planning → prod-manager
      - Architecture decisions, RFCs, ADRs → architect-manager
      - Operational analysis, cost review, process improvement → coo
      - Cross-cutting tasks → delegate to multiple managers in parallel

      ADR enforcement:
      When architect-manager produces a new ADR, note its path. For all subsequent
      tasks that fall within the ADR's scope, include the ADR reference in your
      delegation task string, e.g.: "Conform to ADR-003 (docs/adrs/ADR-003.md)".

      Keep your messages short. Your value is routing accuracy, not commentary.
    '';
    delegatesTo = [
      "eng-manager"
      "qa-manager"
      "prod-manager"
      "architect-manager"
      "coo"
    ];
    managedAgents = [
      "eng-manager"
      "qa-manager"
      "prod-manager"
      "architect-manager"
      "coo"
    ];
    permissions = {
      edit = "deny";
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "eng-manager" = "allow";
          "qa-manager" = "allow";
          "prod-manager" = "allow";
          "architect-manager" = "allow";
          "coo" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [ ];
    mcpServers = [ ];
    orchestration.patterns = {
      "implement-and-review" = ''
        1. Delegate implementation to eng-manager
        2. When eng-manager reports completion, delegate review to qa-manager
        3. If qa-manager reports issues, send them back to eng-manager
        4. When both are satisfied, delegate documentation to prod-manager
      '';
      "adr-driven-implementation" = ''
        1. Delegate ADR/RFC creation to architect-manager
        2. Note the ADR path from architect-manager's response
        3. Delegate implementation to eng-manager with ADR reference in task
        4. Delegate review to qa-manager with ADR reference (validates conformance)
        5. If qa-manager finds ADR violations, send back to eng-manager
      '';
      "operational-review" = ''
        1. Delegate analysis to coo
        2. If coo recommends changes, route to relevant manager
        3. Summarize recommendations to user
      '';
    };
    orchestration.antiPatterns = [
      "Never do implementation work directly — always delegate"
      "Never skip QA review for non-trivial changes"
      "Never route architecture decisions to eng-manager — use architect-manager"
    ];
    overrides = { };
  };
}
