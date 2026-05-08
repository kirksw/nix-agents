# ADR-0002: Profile-Selected OpenShell Sandboxing

- **Status:** Accepted
- **Date:** 2026-05-07
- **Related:** ADR-0001 base/profile hierarchy, OpenShell wrapper support

## Context

Profiles already select agent sets, model tiers, permissions, credentials, and runtime state directories. That leaves process and filesystem isolation outside the declarative model, so launching a profile locally and launching it in a sandbox require different user workflows.

OpenShell provides a common sandbox launcher through `openshell sandbox create`. The wrapper can use that launcher, but a sandboxed command runs in the remote sandbox environment. Therefore wrappers cannot pass local Nix store tool paths as the remote command; they must run the target command name inside the sandbox and upload the generated profile config first.

## Decision

Add named `sandboxes` to the module schema and let each profile opt into one with `profiles.<name>.sandbox`.

`mkProfileMeta` includes the resolved sandbox config for each profile. `mkWrappedTool` selects the active profile as before, syncs generated profile assets locally, and if the active profile has a sandbox, launches:

```bash
openshell sandbox create ... -- env ... <target-command> "$@"
```

The wrapper uploads the generated profile config directory and uploads the current project by default. The remote command defaults to the target name such as `codex`, `claude`, `opencode`, or `pi`, with an override available through `sandboxes.<name>.command`.

## Consequences

- Profile selection now controls both configuration and sandbox isolation.
- Unsandboxed profiles remain possible by leaving `profiles.<name>.sandbox = null`.
- Sandbox images must provide the selected remote command unless `sandboxes.<name>.command` points to an available executable.
- Secrets should be supplied through OpenShell providers or base/profile credential resolution, not embedded in generated config files.
