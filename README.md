# nix-agents

Reusable Nix modules, evaluators, wrappers, and target generators for composing LLM agent configurations.

This repository is intentionally engine-first. It provides the framework for evaluating agent definitions and generating tool-specific assets, but it does not ship a personal or opinionated agent team. Put real agent rosters, skills, profiles, secrets, and local packages in the consuming flake.

## What This Provides

- A Nix module schema for agents, skills, MCP servers, hooks, providers, bases, profiles, and OpenShell sandbox policy.
- Generator functions for OpenCode, Claude Code, Codex, Cursor, Amp, and Pi-compatible config outputs.
- Runtime wrappers via `mkWrappedTool` that select profiles, resolve credentials, sync generated config, and optionally launch through OpenShell sandboxes.
- JSON/TOML schema compatibility checks and a small example template.

## Public API

```nix
nix-agents.lib.${system}.mkAgentSystem
nix-agents.lib.${system}.mkProfileMeta
nix-agents.lib.${system}.mkWrappedTool
nix-agents.lib.${system}.evalModules
nix-agents.lib.${system}.types
```

## Template

Create a small starter flake:

```sh
nix flake init -t github:kirksw/nix-agents
```

The template defines one agent, one skill, one MCP server, a base, and a profile. Treat it as a starting point for your own configuration repository.

## Development

```sh
nix flake check
nix run .#fmt
nix run .#lint
nix run .#bench
```

## Repository Boundary

Keep these here:

- `modules/`
- `lib/`
- `lib/generators/`
- `lib/schemas/`
- `checks/`
- `templates/`

Keep these in a consuming repo:

- concrete agent rosters and prompts
- real skills and MCP declarations
- base/profile policy for a person or organization
- package definitions for local tools or services
- secrets and credential source policy
