---
name: add-module
description: Interactively add any nix-agents module type - agent, skill, MCP server, hook, preset, or profile. Use when the user wants to create a new definition, understand what each module type does, or get step-by-step guidance wiring a new module into the build.
---

# Add Module

Guide the user through adding a new nix-agents module. Ask one focused question at a time. Do not create files until the required fields are confirmed.

Use `nix-agents` for canonical field shapes, style rules, and validation commands. Use the references in this skill for the conversational wizard flow and per-module checklists.

## Workflow

1. Help the user choose the module type.
2. Collect the required fields for that module type.
3. Show the Nix block or file shape that should be created.
4. Explain how to wire it into the build.
5. Validate with format, lint, build, and flake checks.
6. Offer sync instructions if they want the config installed locally immediately.

## Read These References As Needed

- `references/module-types.md`: quick chooser for agent, skill, MCP server, hook, preset, and profile
- `references/agent.md`
- `references/skill.md`
- `references/mcp-server.md`
- `references/hook.md`
- `references/preset.md`
- `references/profile.md`
- `references/wiring-and-validation.md`

## Working Rules

- Ask for one decision at a time rather than dumping the whole schema on the user.
- Explain what each field is for before asking for it.
- Confirm the collected values before creating or showing code.
- Prefer existing repo patterns over inventing new module shapes.
