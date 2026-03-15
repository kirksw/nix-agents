# nix-agents

Composable LLM agent teams as Nix derivations. Define agents, skills, MCP servers, and their delegation graph once — generate configs for OpenCode, Claude Code, Codex, and Pi.

## Architecture

- `lib/core/` — Types, eval, builders (module system plumbing)
- `lib/generators/` — Per-tool config generators (opencode, claude-code, codex, pi, mermaid, agents-md)
- `lib/schemas/` — JSON schemas for generated config validation
- `modules/` — NixOS-style option declarations (system, agent, skill, mcp-server)
- `defs/agents/` — Agent definitions (one per file, sets `agents.<name>`)
- `defs/skills/` — Skill definitions (one per file, sets `skills.<name>`)
- `defs/mcps/` — MCP server definitions
- `targets/pi/` — Pi coding agent: extensions, prompts, package
- `presets/` — Curated module collections (default, minimal, security)
- `templates/` — Flake templates for downstream users
- `evals/` — promptfoo evaluation suites

## Key Conventions

- All Nix files use nixfmt-rfc-style formatting (`nix run .#fmt` or `nix flake check`)
- Use `statix` for linting, `deadnix` for dead code (`nix run .#lint`)
- Agent modules are plain attrsets: `{ agents.<name> = { ... }; }` — no `{ config, lib, ... }:` boilerplate unless needed
- The module system passes `lib`, `types`, and `inputs` as specialArgs
- Generators are curried: `{ lib, config, src? } -> { agents, skills, agentsMd, ... }`
- Model tiers (fast/balanced/powerful/reasoning) resolve per-generator to concrete model strings; override with `tierMapping`
- Permission fields default to `null` — generators fall back to `config.defaultPermissions`

## Testing Changes

After any change to lib/, modules/, defs/, targets/, or generators/:

1. `nix build .#opencode-config` — verify OpenCode config generation
2. `nix build .#claude-config` — verify Claude config generation
3. `nix flake check` — run all checks (format, lint, schema-compat, config-gen, wrapper smoke tests)

## Common Tasks

- **Add an agent**: create `defs/agents/<name>.nix`, import it from a preset
- **Add a skill**: create `defs/skills/<name>.nix`, import it from a preset
- **Add a generator**: create `lib/generators/<target>.nix`, wire into `lib/core/builders.nix`
- **View delegation graph**: `nix run .#graph` (outputs Mermaid)
- **Test evals**: `nix run .#bench` (requires ANTHROPIC_API_KEY)
