# ADR-0003: Generated Model-Tier Manifest Surfaced to Agents

- **Status:** Accepted
- **Date:** 2026-06-14
- **Deciders:** nix-agents maintainers
- **Related:** ADR-0001 (base/profile hierarchy), generator `tierMapping` resolution in `opencode.nix`

## Context

`tierMapping` is **compile-time resolution metadata only**. During generation:

1. `builders.nix` resolves `tierMapping = config.tierMapping // profile.tierMapping`.
2. `opencode.nix` computes `tierModels = generatorDefaults // config.tierMapping` and
   `resolveModel = m: tierModels.${m} or m`.
3. Each agent's `model` field (a tier key such as `balanced`) is replaced with a **concrete
   model id** in the emitted frontmatter.

Consequences:

- The tier abstraction is discarded at generation time.
- The generated agent roster (`agents-md.nix`) emits name, description, and delegation
   patterns only — **no model and no tier**.
- Downstream agents (e.g. pi) therefore cannot reason about:
  - which tier any agent runs at,
  - which models are **peers** at the same tier,
  - what constitutes a tier-equivalent **backup** when an agent fails or stalls,
  - which agent is a valid **same-tier reviewer** for another agent's plan or work.

This blocks common orchestration patterns: sparring two powerful agents, failing over to a
tier-equivalent backup, and peer review across tier-equivalent agents.

## Decision

Emit a **generated model-tier manifest** and surface it in the `AGENTS.md` that targets load
automatically. The manifest is produced by a shared generator from data already computed
during generation, so it can never drift from `tierMapping`.

### Source of truth

The manifest is derived solely from:

- `tierModels` (the resolved `generatorDefaults // config.tierMapping`), and
- `config.agents` (each agent's `model` field).

It introduces no new inputs and is regenerated on every sync.

### Generator location

- New shared generator: `lib/generators/tier-manifest.nix`, shaped
  `{ lib }: { agents, tierModels }: <markdown string>`.
- `opencode.nix` (where `tierModels` already lives) computes and exposes
  `tierManifest` as an output attribute, so any target that reuses the opencode
  generator (pi) inherits it.

### Render target

For pi, the manifest is **appended** to `agentsMd` (the source workflow guide) so the
hand-authored guide is preserved verbatim and the tier section is always present in the
`AGENTS.md` pi loads at startup. Appending (not splicing) keeps generation idempotent and
never clobbers human-authored content.

Other targets (opencode, codex) can consume the same `tierManifest` attribute; initial
wiring is pi-only to match the motivating use case.

### Manifest content

The manifest renders:

1. A **tier → model** table from `tierModels`.
2. An **agents-by-tier** grouping. Agents whose `model` is a key present in `tierModels`
   are grouped under that tier; agents with a concrete (non-tier-key) `model` are listed
   under an "other" group with their literal model id.
3. A short **usage** section explaining the three supported patterns (sparring, backup
   failover, peer review) against same-tier groupings.
4. A note disambiguating **model tier** (`ultrafast/fast/balanced/powerful/reasoning`) from
   **organizational tier** (`employee/manager/orchestrator`).

Markers wrap the section for clarity:

```
<!-- nix-agents:tier-manifest:start -->
...
<!-- nix-agents:tier-manifest:end -->
```

## Consequences

- **Positive:** Agents learn their peers by tier at no config cost; sparring, failover,
  and peer-review patterns become expressible without hardcoding model ids.
- **Positive:** Single source of truth (`tierMapping`); no manual doc drift.
- **Positive:** Shared generator is reusable across targets.
- **Negative:** `AGENTS.md` grows by a generated section; append-only keeps this bounded
  and idempotent.
- **Deployment:** This is an engine change. Consumers pin `nix-agents` to a branch/ref and
  must update their flake lock to consume it (see `nix-config` `nix-agents` input).
