---
name: nix-agents
description: Nix-agents repository workflow for Nix coding style, module definitions, and flake operations. Use when writing or reviewing Nix code in this repo, adding or modifying agents/skills/MCP servers/hooks/presets/profiles, building generated configs, syncing local tool configs, or running validation commands.
---

# Nix-Agents

Use this skill for all repo-specific Nix work in `nix-agents`.

## Read These References As Needed

- `references/coding-style.md`: formatting, linting, and common Nix patterns used here
- `references/module-workflow.md`: module shapes, repository layout, and wiring rules
- `references/flake-ops.md`: build, check, sync, and target-specific commands

## Working Rules

- Follow the repo's Nix style before changing `.nix` files.
- Use the module workflow reference when adding or rewiring defs.
- Use the flake ops reference when validating or syncing changes.
