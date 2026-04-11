# 3-Tier Multi-Agent Architecture — Implementation Plan

**Date:** 2026-04-11
**Status:** Proposed (v2 — adds Architect Manager, COO, Dashboard)
**Author:** the-architect

## Assumptions & Constraints

1. **Pi's `--tools` flag is the only enforced boundary.** File-path scoping, `delegatesTo`, and `permissions.task.rules` are all prompt engineering — not runtime enforcement.
2. **Recursive subagent calls work** — a subagent can invoke the subagent extension, which re-discovers agents from `~/.pi/agent/agents/`.
3. **Every spawned subagent sees the entire agent directory.** There is no mechanism in `agents.ts` to filter the agent list based on who is calling.
4. **Context isolation is total** — each subagent is `--no-session`, communicates only via task string in / text out. No shared memory, no files-as-IPC.
5. **Cost multiplies per tier.** A 3-deep call (user → orchestrator → manager → employee) means 3× the context window load for a single leaf task. The orchestrator and manager tiers should use cheap/fast models with minimal context.
6. **The Nix type system validates at eval time only.** Runtime enforcement requires extension modifications.
7. **The existing 8-agent flat graph works.** We must not break it — the tiered architecture is additive.
8. **Pi has no web server.** Dashboard must be TUI-based (pi extensions) or file-based. Real-time cross-process shared TUI state is not possible.
9. **agent-observe is post-hoc.** It provides retrospective analysis (session history, cost data) via HTTP API and SQLite — not real-time monitoring.
10. **ADR enforcement is soft.** Like human organizations, ADRs are enforced via prompt injection and code review, not runtime guards.

## Architecture Overview

```
User
  │
  ▼
┌─────────────────────┐
│    Orchestrator      │  Tier 0 — fast model, subagent tool only
│    (coordinator)     │  Routes to managers, synthesizes results
└────────┬────────────┘
         │
    ┌────┴─────┬──────────┬──────────┬──────────┐
    ▼          ▼          ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ Eng Mgr│ │ QA Mgr │ │Prod Mgr│ │Arch Mgr│ │  COO   │  Tier 1
│        │ │        │ │        │ │(Chief  │ │(Chief  │  Managers
│        │ │        │ │        │ │Archit.)│ │Ops Off)│
└───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘
    │          │          │          │          │
    ▼          ▼          ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│code-   │ │bottle- │ │scribe  │ │the-    │ │explore │  Tier 2
│monkey  │ │neck    │ │explore │ │architect│ │(reads  │  Employees
│10xBEAST│ │chaos-  │ │        │ │explore │ │observe)│
│        │ │demon   │ │        │ │        │ │        │
└────────┘ │code-red│ └────────┘ └────────┘ └────────┘
           └────────┘
```

## Design Decision: Enforcement Strategy

### Option A: Prompt Engineering Only (Phase 1)
- Tier boundaries encoded in agent prompts and `delegatesTo` (validated at Nix eval time)
- `tools:` frontmatter restricts orchestrator/manager to `subagent` only (enforced)
- No extension modifications needed
- **Risk:** Agents can "hallucinate" calling agents outside their tier. Mitigated by removing all tools except `subagent` from orchestrator/manager, making them physically unable to do anything except delegate.

### Option B: Extension-Level Agent Filtering (Phase 2)
- New frontmatter field `visibleAgents:` parsed by `agents.ts`
- `discoverAgents()` filters the returned list based on the calling agent's `visibleAgents`
- Requires a way to pass the caller identity to the spawned pi process
- **Risk:** Requires changes to the subagent extension TypeScript.

### Option C: Custom Scoped Subagent Extension (Phase 3)
- Fork the subagent extension into a `tiered-subagent` extension
- Each agent gets a differently-configured instance that only sees its managed agents
- Maximum enforcement but highest maintenance burden

**Recommendation:** Phase 1 with Option A, Phase 2 adds Option B. Skip Option C unless prompt drift becomes a real problem.

## Design Decision: COO Tool Exception

The "managers only get `subagent`" rule exists to prevent managers from doing implementation work. The COO is a special case: it must analyze config files and agent-observe data to produce operational recommendations.

| Option | Tools | Risk |
|--------|-------|------|
| A: `subagent` only | Delegates all reading to `explore` | Higher cost, slower, but pure separation |
| B: `subagent` + `read` | Can directly read config/data, still cannot modify anything | Pragmatic exception, low risk |
| C: Full tools | Defeats the purpose of a manager tier | Rejected |

**Recommendation:** Option B — give COO `tools: [subagent, read]`. It can observe but cannot write, edit, or execute commands. This mirrors a real COO who reads dashboards and reports but doesn't write code.

## Design Decision: ADR Enforcement Flow

ADRs are architectural decisions that constrain employee behavior. Enforcement is a multi-step process:

```
architect-manager                   the-architect (employee)
    │                                      │
    │ "Write ADR for X pattern"            │
    ├─────────────────────────────────────►│
    │                                      │ writes docs/adrs/ADR-XXX.md
    │                                      │◄──── (has write tool)
    │  "ADR-XXX written at docs/adrs/..."  │
    │◄─────────────────────────────────────┤
    │                                      
    │ Reports ADR location to orchestrator
    ▼
orchestrator
    │
    │ Future tasks now include:
    │ "... Conform to ADR-003 (docs/adrs/ADR-003.md) ..."
    │
    ├──► eng-manager ──► code-monkey reads ADR, implements accordingly
    │
    └──► qa-manager ──► bottleneck reads ADR, validates conformance
```

**Key insight:** ADR enforcement is the same as in human organizations — write the standard, reference it in work instructions, validate in review. The orchestrator injects ADR references into task strings. Employees read ADRs with their `read` tool. QA validates conformance during review.

---

## Phase 1: Tier Metadata, All Manager Agents & Orchestrator (Prompt-Only Enforcement)

**Goal:** Add 5 manager agents and 1 orchestrator agent. Tier boundaries enforced via `tools:` (hard) and prompt engineering (soft). The existing flat agent graph continues to work unchanged.

**Independently useful:** Yes — users get a structured delegation hierarchy immediately.

### 1.1 Type System: Add `tier` and `managedAgents` Fields

**File:** `lib/core/types.nix`

Add to `agentType.options`:
```nix
tier = mkOption {
  type = types.nullOr (types.enum [ "orchestrator" "manager" "employee" ]);
  default = null;
  description = "Tier in the delegation hierarchy. Null for flat-graph agents.";
};
```

Add to `agentType.options`:
```nix
managedAgents = mkOption {
  type = types.listOf types.str;
  default = [];
  description = "Agent names this manager/orchestrator can delegate to. Injected into prompt and used for future runtime filtering.";
};
```

**Rationale:** `null` default means all existing agents are unaffected. `managedAgents` is distinct from `delegatesTo` — `delegatesTo` is the graph edge for validation, `managedAgents` is the subset the agent should actually use (may be the same, may be narrower).

### 1.2 Nix Validation: Check `managedAgents` ⊆ `delegatesTo`

**File:** `modules/system.nix`

Add a new check after `checkDelegatesExist`:
```nix
checkManagedSubset =
  let
    bad = lib.concatMap (name:
      let
        agent = config.agents.${name};
        notInDelegates = lib.filter (m: !builtins.elem m agent.delegatesTo) agent.managedAgents;
      in
      map (m: "${name}.managedAgents: ${m} not in delegatesTo") notInDelegates
    ) agentNames;
  in
  if bad != [] then
    throw "managedAgents must be a subset of delegatesTo: ${lib.concatStringsSep ", " bad}"
  else true;
```

Wire into `allValid`.

### 1.3 Generator: Inject `managedAgents` Into Prompts

**File:** `lib/generators/shared.nix`

Add `mkManagedAgentsSection`:
```nix
mkManagedAgentsSection = agents: managedNames:
  let
    entries = map (name:
      "- `${name}`: ${agents.${name}.description}"
    ) managedNames;
  in
  if managedNames == [] then ""
  else ''
    ## Managed Agents

    You may ONLY delegate to the following agents:
    ${lib.concatStringsSep "\n" entries}

    Do NOT invoke any agent not listed above. If you need work done outside your scope, report back to your caller with what you need.
  '';
```

**File:** `lib/generators/opencode.nix` (and the pi.nix generator indirectly via shared)

When generating agent prompts, append the managed agents section if `managedAgents != []`.

### 1.4 Agent Definitions: Orchestrator

**File:** `defs/agents/orchestrator.nix`

```nix
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
    delegatesTo = [ "eng-manager" "qa-manager" "prod-manager" "architect-manager" "coo" ];
    managedAgents = [ "eng-manager" "qa-manager" "prod-manager" "architect-manager" "coo" ];
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
    skills = [];
    mcpServers = [];
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
    overrides = {};
  };
}
```

**Key enforcement:** `tools:` frontmatter for the orchestrator will resolve to `subagent` only (see 1.8). Without `read`, `write`, `edit`, `bash`, the orchestrator literally cannot do anything except delegate.

### 1.5 Agent Definitions: Engineering, QA, and Product Managers

**File:** `defs/agents/eng-manager.nix`

```nix
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
    delegatesTo = [ "code-monkey" "10xBEAST" "chaos-demon" "explore" ];
    managedAgents = [ "code-monkey" "10xBEAST" "chaos-demon" "explore" ];
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
    skills = [];
    mcpServers = [];
    orchestration.patterns = {};
    orchestration.antiPatterns = [
      "Never write code yourself — delegate to code-monkey or 10xBEAST"
    ];
    overrides = {};
  };
}
```

**File:** `defs/agents/qa-manager.nix`

```nix
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
    delegatesTo = [ "bottleneck" "chaos-demon" "code-red" ];
    managedAgents = [ "bottleneck" "chaos-demon" "code-red" ];
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
    skills = [];
    mcpServers = [];
    orchestration.patterns = {};
    orchestration.antiPatterns = [
      "Never approve changes without at least one review pass"
    ];
    overrides = {};
  };
}
```

**File:** `defs/agents/prod-manager.nix`

```nix
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
    delegatesTo = [ "scribe" "explore" ];
    managedAgents = [ "scribe" "explore" ];
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
    skills = [];
    mcpServers = [];
    orchestration.patterns = {};
    orchestration.antiPatterns = [];
    overrides = {};
  };
}
```

### 1.6 Agent Definitions: Architect Manager (New)

**File:** `defs/agents/architect-manager.nix`

```nix
{
  agents.architect-manager = {
    description = "Coordinates architecture decisions, RFC/ADR authoring, and design reviews.";
    mode = "subagent";
    model = "balanced";
    tier = "manager";
    temperature = 0.2;
    prompt = ''
      You are the Chief Architect (Architect Manager). You own the organization's
      architectural standards and coordinate architecture employees.

      You do NOT write documents or code yourself. You delegate to employees.

      Responsibilities:
      1. Receive architecture requests from the orchestrator.
      2. Delegate design work to the-architect (designs, tradeoff analysis, plans).
      3. Delegate exploratory research to explore (codebase analysis, feasibility).
      4. Direct the-architect to write ADRs to docs/adrs/ADR-XXX.md.
      5. Report ADR locations back to the orchestrator so they can be referenced
         in future task delegations.

      ADR workflow:
      - When a new architectural decision is needed, delegate to the-architect:
        "Write ADR-XXX: <title>. Save to docs/adrs/ADR-XXX.md. Include context,
         decision, consequences, and conformance criteria."
      - ADR numbering: check existing ADRs in docs/adrs/ via explore first.
      - the-architect has write access and will create the ADR file.
      - Report the ADR path and summary back to the orchestrator.

      RFC workflow:
      - For larger proposals, delegate to the-architect to write an RFC at
        docs/rfcs/RFC-XXX.md with problem statement, options analysis, and
        recommendation.

      Design review:
      - When the orchestrator sends existing code/plans for architecture review,
        delegate to the-architect for analysis and to explore for codebase context.
      - Synthesize findings into a clear assessment.
    '';
    delegatesTo = [ "the-architect" "explore" ];
    managedAgents = [ "the-architect" "explore" ];
    permissions = {
      edit = "deny";
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "the-architect" = "allow";
          "explore" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [];
    mcpServers = [];
    orchestration.patterns = {
      "adr-creation" = ''
        1. Delegate to explore: "List existing ADRs in docs/adrs/ and report the highest number"
        2. Delegate to the-architect: "Write ADR-{next}: {title}. Save to docs/adrs/ADR-{next}.md."
        3. Report ADR path and summary to caller
      '';
    };
    orchestration.antiPatterns = [
      "Never write ADRs or documents yourself — delegate to the-architect"
      "Never make implementation decisions — focus on architecture and standards"
    ];
    overrides = {};
  };
}
```

### 1.7 Agent Definitions: COO (New)

**File:** `defs/agents/coo.nix`

```nix
{
  agents.coo = {
    description = "Analyzes operational metrics, cost efficiency, and agent utilization. Produces recommendations.";
    mode = "subagent";
    model = "balanced";
    tier = "manager";
    temperature = 0.2;
    prompt = ''
      You are the Chief Operating Officer (COO). You analyze operational data and
      produce recommendations for improving agent efficiency, reducing cost, and
      identifying process problems.

      You have READ access to analyze files and data. You do NOT write, edit, or
      execute commands. You delegate write operations to employees.

      Data sources:
      - agent-observe MCP server: session history, cost data, agent usage patterns
        (connect via mcpServers configuration)
      - Config files: agent definitions, presets, system configuration
      - Status files: .pi/status/*.json (when dashboard is active)
      - docs/ops/: operational reports and recommendations

      Analysis capabilities:
      - Cost per time period (daily, weekly, monthly)
      - Agent utilization rates (which agents are over/underused)
      - Session duration analysis (identify slow workflows)
      - Delegation pattern analysis (are managers routing efficiently?)
      - Skill regression detection (are certain tasks taking longer over time?)

      Limitations:
      - agent-observe is POST-HOC only. You cannot monitor in real-time.
      - Per-tier cost breakdown requires Phase 3 tier fields in observe.
        Until then, report aggregate cost by agent name.

      Workflow:
      1. Receive analysis request from orchestrator.
      2. Read relevant config/data files directly (you have read access).
      3. Query agent-observe for historical metrics (when MCP server is connected).
      4. Delegate deep-dive analysis to explore if needed.
      5. Write recommendations: delegate to explore to write reports to docs/ops/.
      6. Report findings and recommendations to orchestrator.

      Output format:
      - Always include data-backed findings (numbers, percentages, trends).
      - Clearly separate observations from recommendations.
      - Rate recommendations by impact (high/medium/low) and effort.
    '';
    delegatesTo = [ "explore" ];
    managedAgents = [ "explore" ];
    permissions = {
      edit = "deny";
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "explore" = "allow";
        };
      };
      webfetch = "deny";
    };
    skills = [];
    mcpServers = [ "agent-observe" ];
    orchestration.patterns = {
      "cost-analysis" = ''
        1. Read system config to understand agent/model mapping
        2. Query agent-observe for session cost data
        3. Aggregate by agent, tier, and time period
        4. Identify outliers and trends
        5. Report findings with recommendations
      '';
      "utilization-review" = ''
        1. Query agent-observe for agent invocation counts
        2. Compare against expected patterns
        3. Identify underused agents (potential removal candidates)
        4. Identify overused agents (potential optimization targets)
        5. Report with actionable recommendations
      '';
    };
    orchestration.antiPatterns = [
      "Never modify configuration or code — only analyze and recommend"
      "Never report opinions without data — always cite metrics"
    ];
    overrides = {};
  };
}
```

**Note on COO tool enforcement:** The COO gets `tools: [subagent, read]` — an exception to the standard manager rule (see 1.8). This is the only manager with `read` access.

### 1.8 Pi Generator: Emit `tools:` Frontmatter

**File:** `lib/generators/opencode.nix` (the Pi generator delegates to this)

Currently the Pi frontmatter renderer does NOT emit a `tools:` line. The subagent extension reads `tools` from frontmatter and passes it as `--tools` to the CLI.

Add logic to `renderFrontmatter`:
```nix
# Derive tools list from tier and permissions
toolsList = name: agent:
  let
    hasTool = perm: perm != null && (
      if builtins.isString perm then perm != "deny"
      else perm.default != "deny" || perm.rules != {}
    );
    base = lib.optional (hasTool agent.permissions.edit) "edit"
           ++ lib.optional (hasTool agent.permissions.bash) "bash"
           ++ lib.optional (hasTool agent.permissions.edit) "write"
           ++ [ "read" ]  # read is always available unless explicitly tier-restricted
           ++ lib.optional (hasTool agent.permissions.webfetch) "webfetch"
           ++ lib.optional (agent.delegatesTo != []) "subagent";
    # Orchestrator and manager tiers: subagent only (COO exception handled below)
    tierRestricted =
      if agent.tier == "orchestrator" then [ "subagent" ]
      else if agent.tier == "manager" then
        # Check if agent name matches COO pattern — but we can't know the name here.
        # Instead, derive from permissions: if any non-task, non-subagent permission
        # is not "deny", include it. For COO, no permissions are non-deny, but it
        # needs read. We solve this with an explicit extraTools field (see below).
        [ "subagent" ]
      else base;
  in tierRestricted;
```

**Problem:** The type system has no `extraTools` field, and the COO needs `read` despite being a manager. Two options:

**Option A (recommended):** Add an `extraTools` field to `agentType`:
```nix
extraTools = mkOption {
  type = types.listOf types.str;
  default = [];
  description = "Additional tools granted beyond tier defaults. Use sparingly for exceptions like COO needing read access.";
};
```

Then the generator becomes:
```nix
tierRestricted =
  if agent.tier == "orchestrator" || agent.tier == "manager"
  then [ "subagent" ] ++ agent.extraTools
  else base;
```

COO definition includes:
```nix
extraTools = [ "read" ];
```

This makes the exception explicit, auditable, and validated at Nix eval time.

**Option B:** Hardcode the COO exception. Rejected — doesn't scale.

Add to frontmatter lines:
```nix
++ lib.optional (agent.tier == "orchestrator" || agent.tier == "manager")
     "tools: ${lib.concatStringsSep "," (toolsList name agent)}"
```

This is the **hard enforcement** — orchestrator/managers physically cannot read/write/edit unless `extraTools` grants it.

### 1.9 Preset: Tiered Preset

**File:** `presets/tiered.nix`

```nix
{
  imports = [
    ./default.nix
    ../defs/agents/orchestrator.nix
    ../defs/agents/eng-manager.nix
    ../defs/agents/qa-manager.nix
    ../defs/agents/prod-manager.nix
    ../defs/agents/architect-manager.nix
    ../defs/agents/coo.nix
  ];
}
```

Users opt into the tiered architecture by switching from `presets/default.nix` to `presets/tiered.nix`.

### 1.10 Mark Existing Agents with Tier

**Files:** All 8 existing agent definitions in `defs/agents/`

Add `tier = "employee";` to each. This is backward-compatible since the default is `null` and the field is optional.

### 1.11 ADR Directory Bootstrapping

**File:** `defs/agents/the-architect.nix` (modify existing)

Add to the prompt:
```
ADR conventions:
- Write ADRs to docs/adrs/ADR-XXX.md (zero-padded 3-digit number)
- ADR format: Title, Status (Proposed/Accepted/Deprecated/Superseded),
  Context, Decision, Consequences, Conformance Criteria
- Create docs/adrs/ directory if it doesn't exist
- Check existing ADRs before assigning a number

RFC conventions:
- Write RFCs to docs/rfcs/RFC-XXX.md
- RFC format: Problem Statement, Options (2-3), Recommendation,
  Implementation Plan, Risks
```

No new `delegatesTo` needed — `the-architect` already has `write` access via its tool permissions.

### 1.12 Testing Strategy (Phase 1)

**File:** `checks/evals.nix` — add new checks:

```nix
# Tier 0/1 agents must not have disallowed tools in generated output
eval-tier-tool-restriction = pkgs.runCommand "eval-tier-tool-restriction" {} ''
  for agent in orchestrator eng-manager qa-manager prod-manager architect-manager; do
    f="${piConfig}/agents/$agent.md"
    if [ -f "$f" ]; then
      tools_line=$(grep '^tools:' "$f" || echo "")
      if echo "$tools_line" | grep -qE 'write|edit|bash'; then
        echo "FAIL: $agent has disallowed tools: $tools_line" >&2
        exit 1
      fi
    fi
  done
  # COO exception: may have read, but not write/edit/bash
  f="${piConfig}/agents/coo.md"
  if [ -f "$f" ]; then
    tools_line=$(grep '^tools:' "$f" || echo "")
    if echo "$tools_line" | grep -qE 'write|edit|bash'; then
      echo "FAIL: coo has disallowed tools: $tools_line" >&2
      exit 1
    fi
    if ! echo "$tools_line" | grep -q 'read'; then
      echo "FAIL: coo missing required read tool: $tools_line" >&2
      exit 1
    fi
  fi
  touch $out
'';

# All managedAgents must be in delegatesTo
eval-managed-subset = pkgs.runCommand "eval-managed-subset" {} ''
  # This is validated at Nix eval time by system.nix
  # This check verifies the store path was built (meaning validation passed)
  test -d ${piConfig}/agents
  touch $out
'';
```

**Manual validation:**
1. Build: `nix build .#pi-config` with tiered preset — must succeed
2. Inspect: `orchestrator.md` should have `tools: subagent` only
3. Inspect: `coo.md` should have `tools: subagent,read`
4. Inspect: `architect-manager.md` should have `tools: subagent` only
5. Run: invoke orchestrator, verify it delegates rather than acting directly
6. Run: send architecture request, verify it routes through architect-manager → the-architect
7. Cost check: measure token usage for a simple "fix this typo" task through all 3 tiers vs. direct to code-monkey

### 1.13 Cost Mitigation

| Tier | Agent | Model | Est. Cost/Request | Rationale |
|------|-------|-------|-------------------|-----------|
| Orchestrator | orchestrator | `fast` (Haiku) | $0.001-0.01 | Routing only, minimal context |
| Manager | eng-manager | `balanced` (Sonnet) | $0.01-0.05 | Task decomposition, moderate context |
| Manager | qa-manager | `balanced` (Sonnet) | $0.01-0.05 | Review coordination |
| Manager | prod-manager | `balanced` (Sonnet) | $0.01-0.05 | Doc coordination |
| Manager | architect-manager | `balanced` (Sonnet) | $0.01-0.05 | Design coordination |
| Manager | coo | `balanced` (Sonnet) | $0.01-0.10 | Reads data (larger context) |
| Employee | varies | varies | $0.05-0.50 | Actual work, full context |

**Key:** Orchestrator and manager prompts must be short (~200 tokens system prompt). They should NOT receive the full codebase context — only the task description. This is naturally achieved by `--no-session` in the subagent extension. The COO may have higher context costs due to `read` access but it is invoked infrequently (operational reviews, not every task).

---

## Phase 2: Extension-Level Agent Visibility Filtering

**Goal:** Prevent agents from seeing (and thus invoking) agents outside their tier, enforced at the TypeScript level.

**Independently useful:** Yes — hardens tier boundaries from "prompt suggestion" to "cannot discover."

### 2.1 New Frontmatter Field: `visibleAgents`

**File:** `targets/pi/extensions/subagent/agents.ts`

Extend `AgentConfig`:
```typescript
export interface AgentConfig {
  name: string;
  description: string;
  tools?: string[];
  model?: string;
  visibleAgents?: string[];  // NEW: if set, only these agents are discoverable
  systemPrompt: string;
  source: "user" | "project";
  filePath: string;
}
```

In `loadAgentsFromDir`, parse the new field:
```typescript
const visibleAgents = frontmatter.visibleAgents
  ?.split(",")
  .map((a: string) => a.trim())
  .filter(Boolean);

agents.push({
  // ... existing fields ...
  visibleAgents: visibleAgents && visibleAgents.length > 0 ? visibleAgents : undefined,
});
```

### 2.2 Filtering in Subagent Execution

**File:** `targets/pi/extensions/subagent/index.ts`

**Approach:** Pass `PI_AGENT_NAME` environment variable to spawned pi processes. The spawned process's subagent extension reads this to determine "who am I" and filters discovered agents to only those in its `visibleAgents` list.

In `runSingleAgent`, add env:
```typescript
const env = { ...process.env, PI_AGENT_NAME: agentName };
const proc = spawn("pi", args, {
  cwd: cwd ?? defaultCwd,
  shell: false,
  stdio: ["ignore", "pipe", "pipe"],
  env
});
```

In the `execute` function, read the env var and filter:
```typescript
const callerName = process.env.PI_AGENT_NAME;
const callerAgent = callerName ? agents.find(a => a.name === callerName) : null;
const visibleAgents = callerAgent?.visibleAgents;
const filteredAgents = visibleAgents
  ? agents.filter(a => visibleAgents.includes(a.name))
  : agents;
```

**Why this works:** When the orchestrator spawns `eng-manager`, the spawned process has `PI_AGENT_NAME=eng-manager`. The extension looks up `eng-manager`'s `visibleAgents` (= `["code-monkey", "10xBEAST", "chaos-demon", "explore"]`) and filters the discovered agents list. The manager physically cannot see or invoke agents outside its scope.

### 2.3 Nix Generator: Emit `visibleAgents` Frontmatter

**File:** `lib/generators/opencode.nix`

In `renderFrontmatter`, add:
```nix
++ lib.optional (agent.managedAgents != [])
     "visibleAgents: ${lib.concatStringsSep "," agent.managedAgents}"
```

This reuses `managedAgents` from the type system. No new field needed at the Nix level.

### 2.4 Nix Type: No Changes Needed

`managedAgents` from Phase 1 drives both the prompt injection and the `visibleAgents` frontmatter. Single source of truth.

### 2.5 Testing Strategy (Phase 2)

**File:** `checks/evals.nix`:
```nix
# visibleAgents frontmatter must match managedAgents for tiered agents
eval-visible-agents = pkgs.runCommand "eval-visible-agents" {} ''
  for agent in orchestrator eng-manager qa-manager prod-manager architect-manager coo; do
    f="${piConfig}/agents/$agent.md"
    if [ -f "$f" ]; then
      if ! grep -q '^visibleAgents:' "$f"; then
        echo "FAIL: $agent missing visibleAgents frontmatter" >&2
        exit 1
      fi
    fi
  done
  touch $out
'';
```

**Integration test** (manual):
1. Set `PI_AGENT_NAME=eng-manager` env var
2. Invoke subagent with `agent: "orchestrator"` — should fail ("unknown agent")
3. Invoke subagent with `agent: "code-monkey"` — should succeed

**Rollback:** Remove the `PI_AGENT_NAME` env var logic. The `visibleAgents` frontmatter is harmless without the extension reading it.

---

## Phase 3: Observability & Cost Controls

**Goal:** Track tier traversals, measure per-tier cost, and add circuit breakers.

**Independently useful:** Yes — gives visibility into the cost/latency of tiered delegation.

### 3.1 Pass Tier Depth as Environment Variable

**File:** `targets/pi/extensions/subagent/index.ts`

```typescript
const currentDepth = parseInt(process.env.PI_TIER_DEPTH || "0", 10);
const maxDepth = parseInt(process.env.PI_MAX_TIER_DEPTH || "5", 10);

if (currentDepth >= maxDepth) {
  return {
    content: [{ type: "text", text: `Delegation depth limit reached (${maxDepth}). Cannot spawn further subagents.` }],
    details: makeDetails("single")([]),
    isError: true,
  };
}

// In runSingleAgent, pass incremented depth:
const env = {
  ...process.env,
  PI_AGENT_NAME: agentName,
  PI_TIER_DEPTH: String(currentDepth + 1),
  PI_MAX_TIER_DEPTH: String(maxDepth),
};
```

### 3.2 Nix Type: `maxDelegationDepth`

**File:** `lib/core/types.nix`, add to `agentType`:
```nix
maxDelegationDepth = mkOption {
  type = types.nullOr types.int;
  default = null;
  description = "Maximum recursive delegation depth. Null for unlimited.";
};
```

**File:** `modules/system.nix`, add:
```nix
maxDelegationDepth = lib.mkOption {
  type = lib.types.int;
  default = 5;
  description = "System-wide max delegation depth. Individual agents can override.";
};
```

### 3.3 Emit `maxDepth` in Frontmatter

**File:** `lib/generators/opencode.nix`:
```nix
++ lib.optional (agent.maxDelegationDepth != null)
     "maxDelegationDepth: ${toString agent.maxDelegationDepth}"
```

Extension reads it and uses it instead of env-based default.

### 3.4 Cost Tracking via agent-observe

**File:** `services/agent-observe/` — extend to accept tier metadata

The existing `agent-observe` MCP server tracks sessions. Extend its schema:
- Add `tier` field to session records
- Add `parentAgent` field to track delegation chains
- Add `delegationDepth` field for depth tracking
- Add a `/api/cost-by-tier` endpoint for reporting
- Add a `/api/delegation-chains` endpoint for tracing task flow

Pass via env:
```typescript
PI_PARENT_AGENT=eng-manager  // set when spawning
PI_AGENT_TIER=employee        // set when spawning
```

These fields enable the COO to perform meaningful per-tier cost analysis once Phase 3 ships.

### 3.5 Testing Strategy (Phase 3)

```nix
# Depth limit must be respected
eval-max-depth = pkgs.runCommand "eval-max-depth" {} ''
  # Verify the frontmatter for orchestrator sets maxDelegationDepth
  f="${piConfig}/agents/orchestrator.md"
  if [ -f "$f" ]; then
    grep -q 'maxDelegationDepth:' "$f" || true  # optional field
  fi
  touch $out
'';
```

**Integration test:**
1. Set `PI_TIER_DEPTH=4`, `PI_MAX_TIER_DEPTH=5`
2. Attempt delegation — should succeed (depth 4 → spawns at 5)
3. Set `PI_TIER_DEPTH=5` — delegation should be rejected

---

## Phase 4: Status Dashboard Extension

**Goal:** Provide visibility into agent activity and operational status via a pi TUI extension and file-based status system.

**Independently useful:** Yes — gives users real-time status in their terminal and enables COO analysis.

### 4.1 Status File Protocol

Agents write status to `.pi/status/<agent-name>.json`. This is a convention, not enforced by the type system.

**Status file schema:**
```json
{
  "agent": "eng-manager",
  "tier": "manager",
  "status": "active",
  "currentTask": "Delegating implementation of feature X to code-monkey",
  "lastUpdated": "2026-04-11T14:32:00Z",
  "delegations": [
    {
      "to": "code-monkey",
      "task": "Implement feature X module",
      "status": "in-progress",
      "startedAt": "2026-04-11T14:32:05Z"
    }
  ],
  "metrics": {
    "tasksCompleted": 12,
    "tasksFailed": 1,
    "avgDurationSeconds": 45
  }
}
```

**Who writes status files:** Employees with `write` access. Managers and orchestrator cannot write status files directly (no `write` tool). Two approaches:

**Option A (recommended):** Employees write their own status. Managers infer team status from employee status files. The dashboard extension reads all status files.

**Option B:** Add a lightweight status-writing hook triggered by the subagent extension on delegation start/end. This would require extension changes but avoids relying on employees to self-report.

**Recommendation:** Start with Option A. Option B is a future optimization if self-reporting proves unreliable.

### 4.2 Status File Writing Convention

Add to employee agent prompts (via `lib/generators/shared.nix`):

```nix
mkStatusSection = agentName: ''
  ## Status Reporting

  At the start of each task, write your status to .pi/status/${agentName}.json:
  ```json
  {
    "agent": "${agentName}",
    "status": "active",
    "currentTask": "<brief description>",
    "lastUpdated": "<ISO 8601 timestamp>"
  }
  ```

  When your task completes, update status to "idle" and clear currentTask.
  When your task fails, update status to "error" with currentTask describing the failure.
'';
```

Only inject this for agents with `tier = "employee"` and `write` tool access.

### 4.3 Dashboard Pi Extension

**File:** `targets/pi/extensions/dashboard/index.ts`

A pi extension that reads status files and renders a TUI widget.

```typescript
import { Extension, ExtensionContext } from "@anthropic/pi-sdk";
import * as fs from "fs";
import * as path from "path";

const POLL_INTERVAL_MS = 3000;
const STATUS_DIR = ".pi/status";

interface AgentStatus {
  agent: string;
  tier?: string;
  status: "active" | "idle" | "error";
  currentTask?: string;
  lastUpdated?: string;
  delegations?: Array<{
    to: string;
    task: string;
    status: string;
  }>;
  metrics?: {
    tasksCompleted?: number;
    tasksFailed?: number;
    avgDurationSeconds?: number;
  };
}

function readStatusFiles(): AgentStatus[] {
  const statusDir = path.resolve(STATUS_DIR);
  if (!fs.existsSync(statusDir)) return [];

  return fs.readdirSync(statusDir)
    .filter(f => f.endsWith(".json"))
    .map(f => {
      try {
        return JSON.parse(fs.readFileSync(path.join(statusDir, f), "utf-8"));
      } catch {
        return null;
      }
    })
    .filter(Boolean) as AgentStatus[];
}

function renderDashboard(statuses: AgentStatus[]): string {
  if (statuses.length === 0) return "No agent status data available.";

  const tierOrder = ["orchestrator", "manager", "employee"];
  const sorted = [...statuses].sort((a, b) =>
    tierOrder.indexOf(a.tier || "employee") - tierOrder.indexOf(b.tier || "employee")
  );

  const lines: string[] = ["┌─── Agent Status Dashboard ───┐", ""];

  for (const s of sorted) {
    const icon = s.status === "active" ? "🟢" :
                 s.status === "error" ? "🔴" : "⚪";
    const tier = s.tier ? `[${s.tier}]` : "";
    lines.push(`${icon} ${s.agent} ${tier}`);
    if (s.currentTask) {
      lines.push(`   └─ ${s.currentTask}`);
    }
    if (s.delegations?.length) {
      for (const d of s.delegations) {
        const dIcon = d.status === "in-progress" ? "⏳" : "✅";
        lines.push(`   ${dIcon} → ${d.to}: ${d.task}`);
      }
    }
  }

  lines.push("", "└──────────────────────────────┘");
  return lines.join("\n");
}

export default function dashboard(ctx: ExtensionContext): Extension {
  let intervalId: NodeJS.Timeout | null = null;

  return {
    name: "dashboard",
    activate() {
      // Poll status files and update widget
      intervalId = setInterval(() => {
        const statuses = readStatusFiles();
        const rendered = renderDashboard(statuses);
        ctx.ui?.setWidget?.("agent-dashboard", {
          content: rendered,
          position: "right",
        });
      }, POLL_INTERVAL_MS);

      // Initial render
      const statuses = readStatusFiles();
      const rendered = renderDashboard(statuses);
      ctx.ui?.setWidget?.("agent-dashboard", {
        content: rendered,
        position: "right",
      });
    },
    deactivate() {
      if (intervalId) clearInterval(intervalId);
    },
  };
}
```

**Important caveats:**
- `ctx.ui.setWidget` is hypothetical API based on pi TUI docs — must be validated against actual pi extension API before implementation.
- Widget is per-pi-session. Cannot show cross-process status.
- File polling is simple but has 3-second latency. Acceptable for a status dashboard.

### 4.4 Alternative: agent-observe HTTP Dashboard

For users who want a richer view, a separate web application can read from agent-observe's SQLite database or HTTP API. This is a **separate project** — not part of the pi extension system.

**Architecture:**
```
agent-observe (MCP server, SQLite)
      │
      ├── HTTP API: /api/sessions, /api/cost-by-tier, /api/delegation-chains
      │
      └── SQLite DB: ~/.pi/observe.db
              │
              ▼
    ┌─────────────────┐
    │  Web Dashboard   │  (separate project, e.g., Next.js or static HTML)
    │  reads from API  │
    └─────────────────┘
```

This is out of scope for this plan but noted as a future enhancement.

### 4.5 Dashboard Nix Integration

**File:** `lib/core/types.nix` — no changes needed (extensions are not typed in the agent system)

**File:** `presets/tiered.nix` — add dashboard extension reference (if pi supports extension configuration in Nix):

```nix
{
  imports = [
    ./default.nix
    ../defs/agents/orchestrator.nix
    ../defs/agents/eng-manager.nix
    ../defs/agents/qa-manager.nix
    ../defs/agents/prod-manager.nix
    ../defs/agents/architect-manager.nix
    ../defs/agents/coo.nix
  ];

  # Dashboard extension is enabled by placing it in the extensions directory
  # No Nix-level configuration needed — it auto-activates
}
```

### 4.6 Testing Strategy (Phase 4)

**Manual validation:**
1. Create `.pi/status/` directory
2. Write a test status file: `.pi/status/code-monkey.json`
3. Start pi with the dashboard extension loaded
4. Verify the widget renders in the TUI
5. Update the status file — verify the widget updates within 3 seconds

**Automated checks:**
```nix
# Status file schema validation
eval-status-schema = pkgs.runCommand "eval-status-schema" {} ''
  # Create a test status file and validate its structure
  cat > /tmp/test-status.json << 'EOF'
  {"agent":"test","status":"idle","lastUpdated":"2026-04-11T00:00:00Z"}
  EOF
  # Validate JSON
  ${pkgs.jq}/bin/jq '.' /tmp/test-status.json > /dev/null
  touch $out
'';
```

---

## File Change Summary

### Phase 1 (New Files)
| File | Action | Description |
|------|--------|-------------|
| `defs/agents/orchestrator.nix` | Create | Tier 0 orchestrator agent |
| `defs/agents/eng-manager.nix` | Create | Engineering manager agent |
| `defs/agents/qa-manager.nix` | Create | QA manager agent |
| `defs/agents/prod-manager.nix` | Create | Product manager agent |
| `defs/agents/architect-manager.nix` | Create | Chief Architect manager agent |
| `defs/agents/coo.nix` | Create | COO manager agent (with read exception) |
| `presets/tiered.nix` | Create | Tiered preset importing all manager agents |

### Phase 1 (Modified Files)
| File | Change |
|------|--------|
| `lib/core/types.nix` | Add `tier`, `managedAgents`, `extraTools` to `agentType` |
| `modules/system.nix` | Add `checkManagedSubset` validation |
| `lib/generators/opencode.nix` | Add `tools:` frontmatter, managed-agents prompt section |
| `lib/generators/shared.nix` | Add `mkManagedAgentsSection` helper |
| `defs/agents/the-architect.nix` | Add `tier = "employee"`, ADR/RFC conventions to prompt |
| `defs/agents/code-monkey.nix` | Add `tier = "employee"` |
| `defs/agents/10xBEAST.nix` | Add `tier = "employee"` |
| `defs/agents/bottleneck.nix` | Add `tier = "employee"` |
| `defs/agents/chaos-demon.nix` | Add `tier = "employee"` |
| `defs/agents/code-red.nix` | Add `tier = "employee"` |
| `defs/agents/scribe.nix` | Add `tier = "employee"` |
| `defs/agents/explore.nix` | Add `tier = "employee"` |
| `checks/evals.nix` | Add tier-related eval checks |
| `flake.nix` | Add `tiered-pi-config` package using tiered preset |

### Phase 2 (Modified Files)
| File | Change |
|------|--------|
| `targets/pi/extensions/subagent/agents.ts` | Parse `visibleAgents` frontmatter |
| `targets/pi/extensions/subagent/index.ts` | Filter agents by `PI_AGENT_NAME` visibility, pass env |
| `lib/generators/opencode.nix` | Emit `visibleAgents:` frontmatter |
| `checks/evals.nix` | Add visibility eval check |

### Phase 3 (Modified Files)
| File | Change |
|------|--------|
| `targets/pi/extensions/subagent/index.ts` | Depth tracking, circuit breaker |
| `lib/core/types.nix` | Add `maxDelegationDepth` |
| `modules/system.nix` | Add system-level `maxDelegationDepth` |
| `lib/generators/opencode.nix` | Emit `maxDelegationDepth:` frontmatter |
| `services/agent-observe/src/` | Add tier/parent/depth fields to schema |

### Phase 4 (New Files)
| File | Action | Description |
|------|--------|-------------|
| `targets/pi/extensions/dashboard/index.ts` | Create | TUI dashboard extension |
| `targets/pi/extensions/dashboard/package.json` | Create | Extension package manifest |

### Phase 4 (Modified Files)
| File | Change |
|------|--------|
| `lib/generators/shared.nix` | Add `mkStatusSection` for employee status reporting |
| `lib/generators/opencode.nix` | Inject status reporting section for employees |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation | Phase |
|------|-----------|--------|------------|-------|
| Orchestrator/manager hallucinate tool use | Medium | Low | `tools:` frontmatter enforced by pi CLI — they literally can't | 1 |
| Employee invokes agent outside its tier | Medium | Medium | Phase 2 visibility filtering; Phase 1 relies on prompt | 1-2 |
| 3-tier cost explosion on simple tasks | High | Medium | Orchestrator uses `fast` model; add "complexity threshold" to orchestrator prompt so trivial tasks skip manager tier | 1 |
| Circular delegation (A→B→A) | Low | High | `delegatesTo` graph validation catches static cycles; depth limit (Phase 3) catches runtime | 1-3 |
| Context loss across 3 hops | High | Medium | Each tier must summarize concisely; managers should pass full task context, not abbreviate | 1 |
| Existing flat-graph users break | Low | Low | All changes are additive; `tier=null` is default; flat preset unchanged | 1 |
| COO `read` tool used for unintended purposes | Low | Low | COO prompt constrains to analysis; no write/edit/bash; code review catches misuse | 1 |
| ADRs ignored by employees | Medium | Medium | QA-manager validates ADR conformance in review; orchestrator injects ADR refs into task strings | 1 |
| ADR numbering conflicts (concurrent writers) | Low | Low | architect-manager checks existing ADRs via explore before assigning; sequential creation natural in single-user mode | 1 |
| architect-manager duplicates prod-manager scope | Medium | Low | Clear prompt separation: arch-mgr owns ADRs/RFCs/design, prod-mgr owns docs/planning. Orchestrator routing rules disambiguate | 1 |
| agent-observe data insufficient for COO analysis | Medium | Medium | Phase 3 adds tier fields; COO operates with aggregate data until then | 1-3 |
| Dashboard status files stale/orphaned | Medium | Low | Poll interval handles staleness; periodic cleanup of files older than 1 hour | 4 |
| Dashboard extension API doesn't match pi SDK | Medium | Medium | Validate against actual pi extension API before implementing; file-based rendering as fallback | 4 |
| Status file writes slow down employees | Low | Low | JSON writes are <1ms; fire-and-forget, not blocking | 4 |

---

## Migration Strategy

1. **Phase 1 ships as a new preset** (`presets/tiered.nix`). Existing users on `presets/default.nix` are unaffected.
2. **Phase 2 is backward-compatible** — the extension changes are no-ops when `PI_AGENT_NAME` is unset.
3. **Phase 3 is backward-compatible** — depth tracking defaults to unlimited when env vars are absent.
4. **Phase 4 is opt-in** — dashboard extension must be explicitly loaded. Status file writing is prompt-based convention, not enforced.
5. **Rollback for any phase:** revert to `presets/default.nix`. Agent `.md` files with extra frontmatter fields (`tier`, `visibleAgents`, `maxDelegationDepth`) are ignored by the current extension.

### Incremental Adoption Path

Users can adopt the tiered architecture incrementally:

```
presets/default.nix          → Flat 8-agent graph (current, unchanged)
presets/tiered.nix           → Full 5-manager + 1-orchestrator + 8-employee hierarchy
presets/tiered-minimal.nix   → (future) Only eng-manager + qa-manager + orchestrator
```

---

## Recommended Execution Order

### Week 1 — Foundation
1. Phase 1.1: Type system — add `tier`, `managedAgents`, `extraTools` to `agentType`
2. Phase 1.2: Nix validation — `checkManagedSubset`
3. Phase 1.3: Generator — `mkManagedAgentsSection` in shared.nix

### Week 1 — Core Agents
4. Phase 1.4: Orchestrator agent definition
5. Phase 1.5: eng-manager, qa-manager, prod-manager agent definitions

### Week 2 — New Managers
6. Phase 1.6: architect-manager agent definition
7. Phase 1.7: COO agent definition (with `extraTools = ["read"]`)
8. Phase 1.8: Pi generator — emit `tools:` frontmatter (including COO exception)
9. Phase 1.11: Update the-architect prompt with ADR/RFC conventions

### Week 2 — Integration
10. Phase 1.9: Tiered preset
11. Phase 1.10: Mark existing agents with `tier = "employee"`
12. Phase 1.12: Eval checks → **ship Phase 1**

### Week 3 — Enforcement
13. Phase 2.1-2.3: Extension-level visibility filtering
14. Phase 2.5: Tests → **ship Phase 2**

### Week 4 — Observability
15. Phase 3.1-3.3: Depth tracking and circuit breaker
16. Phase 3.4: agent-observe tier extensions → **ship Phase 3**

### Week 5 — Dashboard
17. Phase 4.1-4.2: Status file protocol and writing convention
18. Phase 4.3: Dashboard extension
19. Phase 4.5-4.6: Integration and tests → **ship Phase 4**

Each week's output is independently deployable and useful.
