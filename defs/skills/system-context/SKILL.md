---
name: system-context
description: Local system and nix-agents setup context for this operator. Use when deciding whether a change should happen declaratively in Nix, locating the source of truth for agent/tool configuration, understanding where generated configs and session data live, or reasoning about personal/work bases and profiles on this machine.
---

# System Context

Use this skill when work depends on how this machine and `nix-agents` are organized.

## Read These References As Needed

- `references/source-of-truth.md`: where changes should usually happen and what generated files not to edit directly
- `references/layout.md`: important repo paths, generated config roots, and session/state locations
- `references/bases-and-profiles.md`: how base/profile selection works on this machine

## Working Rules

- Prefer declarative changes in Nix-managed source over ad hoc edits to generated config.
- For `nix-agents` behavior, treat the repo as the source of truth and `~/.config/nix-agents/...` as generated output.
- Before editing a path under `~/.config/nix-agents`, ask whether the change should instead be made in the flake, presets, defs, or profiles and then synced or rebuilt.
