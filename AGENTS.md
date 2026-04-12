# Multi-Agent Workflow

You have access to specialized subagents via the `subagent` tool. Use them to produce better
results by matching work to the right agent instead of doing everything yourself.

## When to Delegate

Delegate when the task benefits from a specialized role. Do not delegate trivial work — only
use subagents when the specialization adds clear value (stronger model, constrained permissions,
domain focus).

## Effective Patterns

**Plan then execute**: For complex features, send the problem to `the-architect` first. Take its
plan and hand it to `code-monkey` for implementation. If the plan is flawed, `code-monkey` can
escalate to `10xBEAST` who will challenge `the-architect` and force a corrected plan.

**Implement then review**: After implementation is complete, send the changes to `bottleneck`
for a quality check before committing. `10xBEAST` may finish straightforward work itself,
but will solve the hard part and hand remaining work back to `code-monkey` when possible.
`code-monkey` owns review delegation.

**Default to code-monkey**: `code-monkey` handles the majority of tasks. It will escalate to
`10xBEAST` when blocked, when requirements are ambiguous, or when it needs a decision forced.

**Unblock with 10xBEAST**: When progress stalls — bad plans, conflicting requirements,
complex cross-cutting problems — send it to `10xBEAST` to break through.

**Chaos check**: Run `chaos-demon` on anything that touches external dependencies, shared
state, async flows, or transactional logic. It reports breakage only — no fixes. Feed its
output to `code-monkey` or `10xBEAST` to decide what to address. `the-architect`, `code-monkey`,
and `10xBEAST` can all invoke it directly.

**Security as a gate**: Run `code-red` on sensitive changes (secrets handling, network
config, auth, dependency updates) before finalizing.

**Document after delivery**: Invoke `scribe` at the end of a session or after a significant
deliverable. `scribe` reads git commits as the changelog and writes or updates session logs,
`README.md`, `ARCHITECTURE.md`, and reference docs. `code-monkey` owns scribe invocation
after completing work. `10xBEAST` invokes `scribe` only when finishing work itself.

## Work Decomposition

Before starting implementation, break the work into logical, commit-sized chunks. Each chunk
should be independently committable and describable in one line. This gives `scribe` a clean
git log to document from and makes review by `bottleneck` more effective. Commit each chunk
as you complete it — do not batch unrelated changes into a single commit.

## ADR / RFC Discipline

When making large architectural, workflow, or policy decisions, create an ADR/RFC in `docs/adr/`
or the appropriate docs location, and link it in follow-up work (PRs, plans, implementation notes).
After implementing the change, review the touched code paths against the new ADR/RFC to verify
compliance and capture any intentional deviations.

- ADR index: `docs/adr/README.md`
- Example: `docs/adr/ADR-0001-base-profile-hierarchy.md`

## Branching and PR Strategy

Use distinct branches per feature/request to keep scope clear and reviewable. If work overlaps,
prefer a stacked PR approach (base PR + follow-up PRs) rather than mixing unrelated changes.

Before starting a new request, ensure the current work is wrapped up (committed, reviewed as needed,
and documented) so context and ownership remain clear.

## Context Management

Use `swe-pruner-mcp` skill when reading large files (>500 lines) or searching codebases with many matches. The MCP tools `read_pruned` and `search_pruned` reduce token usage by 23-54% by returning only context-relevant code.

## Anti-Patterns

- Do not delegate a task to multiple implementation agents in parallel on the same files.
- Do not use `the-architect` for implementation — it is intentionally restricted to design output.
- Do not skip `bottleneck` on significant changes just to save time.
- Do not send trivial one-line fixes to `10xBEAST` — handle them directly or use `code-monkey`.
