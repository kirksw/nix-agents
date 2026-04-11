# Phase 1 3-Tier Architecture Implementation — 2026-04-11

## Goal

Implement Phase 1 of the 3-tier multi-agent architecture: add tier-aware type system, create 6 new manager-tier agents, configure tool restrictions via frontmatter, and establish validation checks in the Nix build.

## Commits

- `46322fb` feat(types): add tier, managedAgents, extraTools fields to agentType + checkManagedSubset validation
- `70e6900` fix(flake): remove unused mkTieredConfig binding, keep tiered-pi-config package

## Changes

### Type System

- Added `tier` (string) field to `agentType` in `lib/core/types.nix`
- Added `managedAgents` (list of strings) field to track which agents report to a manager
- Added `extraTools` (list of strings) field to specify tool exceptions (e.g., COO gets `read`)
- Added `checkManagedSubset` validation in `modules/system.nix` to ensure managers only reference agents that exist

### New Agents

Created 6 new agent definitions:
- **orchestrator** (tier 0) — fast coordinator, routes to managers, synthesizes results. Only tool: `subagent`
- **eng-manager** (tier 1) — manages code-monkey, 10xBEAST. Tools: `subagent` only
- **qa-manager** (tier 1) — manages bottleneck, chaos-demon. Tools: `subagent` only
- **prod-manager** (tier 1) — manages scribe, explore. Tools: `subagent` only
- **architect-manager** (tier 1) — manages the-architect, explore. Tools: `subagent` only
- **coo** (tier 1) — Chief Operations Officer, manages explore. Tools: `subagent` + `read` (exception for config/data analysis)

### Existing Agents

Added `tier = "employee"` to all 8 existing agents (code-monkey, 10xBEAST, bottleneck, chaos-demon, code-red, the-architect, scribe, explore).

### Code Generation

- Added `mkManagedAgentsSection` helper in `lib/generators/shared.nix` to inject managed-agents list into agent prompts
- Updated `opencode.nix` generator to emit `tools:` and `visibleAgents:` frontmatter fields for tiered agents
- Orchestrator and manager agents get `tools: [subagent]` in frontmatter (enforced by pi CLI)
- COO gets `tools: [subagent, read]`

### Configuration & Presets

- Created `presets/tiered.nix` — bundles all tier-aware agents and orchestrator configuration
- Added `tiered-pi-config` package to `flake.nix` that assembles the tiered preset into a distributable pi config

### Validation Checks

Added to `checks/evals.nix`:
- `eval-tier-tool-restriction` — verifies tier 0/1 agents have no tools except `subagent` (or `subagent` + `read` for COO)
- `eval-visible-agents` — checks that all tiered agents specify `visibleAgents` in frontmatter
- `eval-managed-subset` — ensures `managedAgents` lists reference only valid agent names

### Documentation

- Added ADR/RFC authoring conventions to the-architect prompt
- Plan document at `docs/plans/2026-04-11-3-tier-architecture.md` (1400+ lines detailing rationale, design decisions, phase roadmap)

### Cleanup

Removed unused `mkTieredConfig` binding from `flake.nix` to keep the derivation simple.

## Build Status

All builds pass. Nix eval and derivations compile without errors.

## Diagram

```
User
  │
  ▼
┌──────────────────┐
│   Orchestrator   │ Tier 0
│   (tier=0)       │ tools: [subagent]
└────────┬─────────┘
         │
    ┌────┴──────┬──────────┬──────────┬──────────┐
    ▼           ▼          ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│eng-mgr │ │qa-mgr  │ │prod-mgr│ │arch-mgr│ │  coo   │ Tier 1
│(tier=1)│ │(tier=1)│ │(tier=1)│ │(tier=1)│ │(tier=1)│ tools: [subagent]
└───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘ │tools:  │ coo: [subagent, read]
    │          │          │          │      │[s, r]  │
    ▼          ▼          ▼          ▼      └────────┘
 [code-        [bottle-   [scribe,  [the-arch,
  monkey,       neck,      explore]  explore]
  10xBEAST]    chaos-d,
               code-red]
                
               Tier 2 (employees)
```

## Outcome

**Done.** Phase 1 architecture implemented and building. Tier system in place, manager agents created, tool restrictions enforced via frontmatter, validation checks added.

The flat 8-agent structure remains unchanged. The 6-agent tiered structure is opt-in via the `tiered.nix` preset. Next phase will add agent-list filtering at the pi extension level (`visibleAgents` parsing in `agents.ts`).

## Follow-up

- Phase 2: Implement `visibleAgents` filtering in pi's subagent extension (requires TypeScript changes to `agents.ts`)
- Phase 2: Add dashboard TUI extension or file-based status reporting
- Monitor agent-observe cost tracking for 3-tier vs flat overhead
- Document runbook for rotating manager coverage (e.g., when to delegate to orchestrator vs calling managers directly)
