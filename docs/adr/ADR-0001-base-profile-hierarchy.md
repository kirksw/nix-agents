# ADR-0001: Base/Profile Hierarchy for Agent Runtime Configuration

- **Status:** Accepted
- **Date:** 2026-04-12
- **Deciders:** nix-agents maintainers
- **Related:** 3-tier architecture planning docs, profile-aware wrappers, Pi `PI_CODING_AGENT_DIR` support

## Context

nix-agents currently supports profile-aware configuration generation and wrapper selection (e.g., `work`, `personal`), but runtime state handling is inconsistent across targets and too coarse for real-world separation requirements.

In practice, users need two distinct concerns:

1. **Environment isolation** (e.g., work vs personal) for sensitive/runtime state such as:
   - API credentials and OAuth state
   - provider authentication files
   - model registries and account-scoped settings
   - sessions and conversation history
2. **Configuration variants** within an environment (e.g., stable vs team vs extreme), where variants mostly differ in:
   - agent graph and delegation policy
   - model tier mappings
   - prompt strictness and skill/tool enablement
   - permission posture

Current profile-only semantics blur these concerns. A profile name currently carries both environment identity and configuration variant, making it hard to express shared auth across related variants while preserving strict isolation between environments.

## Decision

Adopt a **two-level namespace**:

- **Base** = runtime-state boundary (security/account/environment boundary)
- **Profile** = configuration overlay within a base

Canonical naming:

- `<base>/<profile>` (examples: `work/stable`, `work/team`, `personal/stable`, `personal/extreme`)

### Semantics

1. **Base owns shared runtime state**
   - Credentials/auth artifacts are shared across all profiles in the same base.
   - Runtime state (sessions/models/settings where appropriate) is scoped at base level unless explicitly overridden by target policy.

2. **Profile owns configuration**
   - Profiles are build-time/runtime configuration overlays on top of a base.
   - Profile changes should not require separate auth/login by default.
   - Profiles should be cheap to create and switch.

3. **Isolation guarantee**
   - No runtime credential/auth sharing across bases.
   - `work/*` and `personal/*` are hard-isolated by directory and wrapper resolution.

4. **Composition model**
   - Effective runtime context is: `base` + `profile overlay`.
   - If a profile omits a field, it inherits from base defaults/system defaults.

## Directory and Wrapper Model

This ADR defines target-agnostic semantics first; concrete paths are implementation details but should follow this pattern:

- Config root: `~/.config/nix-agents/<target>/bases/<base>/profiles/<profile>/...`
- Base state root: target-specific runtime dir under `.../bases/<base>/state` (or tool-native equivalent)

For Pi specifically, wrappers should evolve from profile-only directories to base/profile-aware directories:

- Base runtime state directory (Pi): base-scoped auth/models/sessions/settings
- Profile config directory (Pi): agents/skills/extensions/prompts + generated docs
- `PI_CODING_AGENT_DIR` points to active profile path, with explicit links/mounting from base state where required

## Consequences

### Positive

- Clear separation of security boundary (base) vs behavior variant (profile)
- Reduced login/auth churn when switching profiles within same base
- Explicit, auditable isolation between work and personal environments
- Better portability across targets with a uniform conceptual model

### Negative / Costs

- Wrapper logic becomes more complex (base + profile resolution)
- Migration required from single-level profile naming
- Additional validation surface in module types and graph checks

## Alternatives Considered

### 1) Keep single-level profiles only

Rejected: cannot cleanly model shared auth within environment and strict auth isolation across environments without brittle naming conventions and ad hoc link behavior.

### 2) Full isolation per profile (no sharing)

Rejected: secure but operationally heavy; duplicates auth and model/session setup for closely related variants (e.g., `work/stable` vs `work/team`).

### 3) Share everything globally (current Pi-like behavior in places)

Rejected: violates security/isolation expectations for work vs personal boundaries.

## Migration Plan

1. Introduce base/profile schema in module options (non-breaking)
   - Continue accepting existing flat profile names
   - Treat flat names as implicit `default/<name>` during transition

2. Add wrapper support for base/profile resolution
   - Resolve active base first, then profile
   - Compute target config/state paths accordingly

3. Update sync/build outputs to emit base/profile layout

4. Add validation checks
   - Base existence and reference integrity
   - Profile must reference valid base
   - No cross-base state links

5. Deprecate flat profile naming after transition window

## Implementation Notes (Initial)

- Prioritize Pi wrapper update first due to explicit `auth.json` and shared runtime state behavior.
- Add helper in builders for normalized `{ base, profile }` selection.
- Ensure `mkProfileMeta` (or successor metadata) includes base-level provider/auth context.
- Preserve existing profile auto-detection mechanisms (`.nix-agents-profile`, path prefixes) by allowing `<base>/<profile>` identifiers.

## Open Questions

1. Should sessions be base-scoped by default for all targets, or target-specific?
2. Should model registry be base-scoped always, or optionally profile-scoped?
3. How should forced profile flags represent base/profile (`--profile work/stable` vs separate flags)?
4. Do we need a first-class `bases` module type, or encode base in profile key during phase 1?

## Example

- `work/stable`: conservative model tiers, stricter permissions, shared work auth
- `work/team`: team-optimized delegation and MCP tools, same work auth
- `personal/stable`: personal defaults, stable behavior, shared personal auth
- `personal/extreme`: aggressive delegation/automation, same personal auth

This captures the intended operating model: **bases isolate identity and sensitive runtime state; profiles select behavior.**
