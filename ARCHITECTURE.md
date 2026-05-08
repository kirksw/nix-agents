# Architecture

`nix-agents` is a small engine for turning Nix module definitions into tool-specific agent configuration directories and wrapped executables.

## Layers

1. **Schema modules** (`modules/`) declare the configuration surface: agents, skills, MCP servers, hooks, providers, bases, profiles, and sandboxes.
2. **Evaluator** (`lib/core/eval.nix`) composes the schema modules with caller-provided modules.
3. **Builders** (`lib/core/builders.nix`) provide the public API:
   - `mkAgentSystem` evaluates modules and writes generated config assets.
   - `mkProfileMeta` builds per-profile config outputs and runtime metadata.
   - `mkWrappedTool` wraps upstream tool binaries with profile detection, credential resolution, config sync, and optional OpenShell sandbox launch.
4. **Generators** (`lib/generators/`) render target-specific files for OpenCode, Claude Code, Codex, Cursor, Amp, and Pi.
5. **Schemas and checks** (`lib/schemas/`, `checks/`) keep generated files compatible with target tools.

## Ownership Model

This repository owns reusable framework behavior only. Consuming flakes own concrete configuration: agents, skills, MCP servers, bases, profiles, secrets, and local packages.

## Runtime Layout

Wrapped tools sync generated assets into:

```text
~/.config/nix-agents/<tool>/bases/<base>/profiles/<profile>/
```

Base-scoped tool state can live beside profile directories, for example Pi uses:

```text
~/.config/nix-agents/pi/bases/<base>/state/
```

## Sandbox Support

Profiles may reference named `sandboxes`. When present, wrappers launch through `openshell sandbox create`, upload the profile config and optionally the current project, and then execute the selected tool inside the sandbox.
