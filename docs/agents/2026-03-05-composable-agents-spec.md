# nix-agents: Composable LLM Agents as Nix Derivations

**Date:** 2026-03-05
**Status:** Approved
**Author:** Kirk Sweeney

## Problem

Agent definitions are duplicated across `~/.config/opencode/agents/`, `~/.claude/agents/`, and (soon) Codex configs. Each tool has its own format but the semantic content — agent identity, delegation rules, permissions, skills, MCP servers — is shared. Changes require updating multiple files in multiple locations. The `AGENTS.md` orchestration document is also duplicated.

## Goal

Define the agent team **once** in Nix. From a single source of truth, generate:
- **OpenCode:** `agents/*.md`, `skills/*/SKILL.md`, `opencode.json`, `AGENTS.md`
- **Claude Code:** `agents/*.md`, `skills/*/SKILL.md`, `settings.json`, `CLAUDE.md`, `.mcp.json`
- **Codex:** `agents/*.md`, `AGENTS.md`, and whatever Codex supports today

The result is a **Nix flake** that can be:
1. Used directly via `nix run` / direnv (standalone wrapper scripts)
2. Imported into other flakes as a library to compose custom agent teams
3. Extended by consumers who add their own agents/skills

## Decisions

| Decision | Choice |
|----------|--------|
| Goal | Single-source definitions + shareable flake |
| Composition | Graph-aware with validation assertions |
| MCP servers | Optional Nix packages (agents can reference local or remote) |
| Codex support | Best-effort parity with extension points |
| Consumer model | Standalone wrappers via `nix run` / direnv |
| Skills | First-class but optional (Nix module OR raw path) |
| AGENTS.md | Auto-generated from graph with per-agent prose overrides |
| Permissions | Common model + per-tool overrides |
| Project configs | Via `nix flake init` template only (not managed ongoing) |

---

## Architecture

### Directory Layout

```
nix-agents/
├── flake.nix                    # Entry point — lib, packages, devShells, templates, checks
├── flake.lock
├── lib/
│   ├── types.nix                # Option type definitions (agent, skill, mcp-server, permission)
│   ├── eval.nix                 # Module evaluation wrapper (lib.evalModules)
│   ├── builders.nix             # mkAgent, mkSkill, mkMcpServer, mkAgentSystem, mkWrappedTool
│   └── generators/
│       ├── opencode.nix         # Evaluated modules → OpenCode config directory
│       ├── claude-code.nix      # Evaluated modules → Claude Code config directory
│       ├── codex.nix            # Evaluated modules → Codex config directory
│       └── agents-md.nix        # Agent graph → AGENTS.md orchestration document
├── modules/
│   ├── agent.nix                # NixOS-style module for a single agent
│   ├── skill.nix                # NixOS-style module for a single skill
│   ├── mcp-server.nix           # NixOS-style module for an MCP server
│   └── system.nix               # Top-level module composing agents + skills + mcp + validation
├── agents/                      # Built-in agent definitions (one per file)
│   ├── code-monkey.nix
│   ├── the-architect.nix
│   ├── 10xBEAST.nix
│   ├── bottleneck.nix
│   ├── chaos-demon.nix
│   ├── code-red.nix
│   ├── scribe.nix
│   └── explore.nix
├── skills/                      # Built-in skill definitions
│   ├── swe-pruner-mcp.nix
│   ├── nix-coding-style.nix
│   ├── nix-flake-ops.nix
│   ├── nix-module-workflow.nix
│   └── skill-creator.nix
├── mcp-servers/                 # Built-in MCP server definitions
│   └── swe-pruner.nix
├── presets/                     # Pre-composed agent teams
│   └── default.nix              # The current 8-agent team with all skills and MCP servers
└── templates/
    └── default/                 # nix flake init template
        ├── flake.nix
        └── agents/
            └── my-agent.nix
```

---

## Core Type System

### Agent Type

```nix
{
  name             : str           # "code-monkey"
  description      : str           # One-line description for tool UIs
  model            : str           # "anthropic/claude-sonnet-4-5"
  mode             : enum          # "subagent" | "primary"
  temperature      : float (0-2)   # 0.2
  reasoningEffort  : nullOr enum   # null | "low" | "medium" | "high" | "xhigh"
  prompt           : lines         # The system prompt (markdown body)

  # Delegation graph
  delegatesTo      : listOf str    # ["bottleneck", "explore", "scribe"]

  # Permissions (unified model, generated per-tool)
  permissions = {
    edit           : permissionSet  # { default = "allow"; rules = { "*.md" = "allow"; }; }
    bash           : permissionSet  # { default = "deny"; rules = { "git diff*" = "allow"; }; }
    task           : permissionSet  # { default = "deny"; rules = { "explore" = "allow"; }; }
    webfetch       : permission     # "allow" | "deny" | "ask"
  };

  # Composition
  skills           : listOf str    # ["swe-pruner-mcp"] — resolved at eval time
  mcpServers       : listOf str    # ["swe-pruner"] — resolved at eval time

  # Orchestration (for AGENTS.md generation)
  orchestration = {
    patterns       : attrsOf lines  # {"Plan then execute" = "prose...";}
    antiPatterns   : listOf str     # ["Do not use the-architect for implementation."]
  };

  # Tool-specific overrides (escape hatch)
  overrides = {
    opencode       : attrs         # Extra frontmatter keys for OpenCode
    claudeCode     : attrs         # Extra frontmatter keys for Claude Code
    codex          : attrs         # Extra frontmatter keys for Codex
  };
}
```

### Skill Type

```nix
{
  name             : str           # "swe-pruner-mcp"
  description      : str           # For tool discovery UIs
  content          : lines         # Markdown body of SKILL.md

  # Optional: bundled resources (scripts, references)
  resources        : attrsOf path  # { "scripts/init.py" = ./scripts/init.py; }

  # Or: raw path to an existing SKILL.md directory
  src              : nullOr path   # ./skills/swe-pruner-mcp/ (takes precedence over content)
}
```

### MCP Server Type

```nix
{
  name             : str           # "swe-pruner"
  enabled          : bool          # true
  type             : enum          # "local" | "remote"

  # For local (stdio) servers
  command          : listOf str    # ["/nix/store/.../bin/swe-pruner-mcp"]
  package          : nullOr pkg    # Optional: Nix package for the server binary

  # For remote (HTTP/SSE) servers
  url              : nullOr str    # "https://api.z.ai/api/mcp/..."
  headers          : attrsOf str   # { Authorization = "Bearer {env:zai_token}"; }

  # Environment for local servers
  environment      : attrsOf str   # { MODEL_PATH = "..."; }
}
```

### Permission Types

```nix
permission     = enum [ "allow" "deny" "ask" ]
permissionSet  = {
  default : permission
  rules   : attrsOf permission    # glob-pattern → permission
}
```

---

## Graph Validation

Assertions evaluated at Nix build time in `modules/system.nix`:

1. Every `delegatesTo` target must exist as a defined agent
2. No self-delegation (`agent.delegatesTo` must not contain `agent.name`)
3. Task permission rules reference only existing agents
4. Every skill in `agent.skills` must exist in `system.skills`
5. Every `mcpServer` in `agent.mcpServers` must exist in `system.mcpServers`
6. At least one agent with `mode = "primary"` should exist (warning)
7. Warn on unreachable agents (no inbound delegation and `mode != primary`)

These produce clear Nix evaluation errors, similar to NixOS module assertions.

---

## Generators

### OpenCode Generator (`lib/generators/opencode.nix`)

**Agent → markdown with YAML frontmatter:**
- Maps `description`, `mode`, `model`, `temperature`, `reasoningEffort` to frontmatter fields
- Maps `permissions.task.rules` to `permission.task` glob rules
- Maps `permissions.bash` to `permission.bash` glob rules
- Maps `permissions.edit` to `permission.edit` glob rules
- Merges `overrides.opencode` into frontmatter
- Appends `prompt` as markdown body

**MCP → JSON entries in `opencode.json` under `mcp` key:**
- Local servers: `{command, environment, type: "local", enabled}`
- Remote servers: `{url, headers, type: "remote", enabled}`
- If `package` is set, uses `${package}/bin/<name>` in command

**Skills → `skills/<name>/SKILL.md`:**
- If `src` is set, copies the directory
- Otherwise generates SKILL.md from `content` with optional frontmatter

**AGENTS.md → from agent graph:**
- Collects `orchestration.patterns` across all agents, groups by pattern name
- Collects `orchestration.antiPatterns`
- Generates sections: header, When to Delegate, Effective Patterns, Work Decomposition, Context Management, Anti-Patterns
- For delegation edges with no explicit pattern, generates default prose

### Claude Code Generator (`lib/generators/claude-code.nix`)

**Agent → markdown with YAML frontmatter:**
- Maps `description`, `model` to frontmatter
- Maps `delegatesTo` to allowed subagent invocations
- Maps permissions to Claude Code's `allow`/`deny`/`ask` format
- Merges `overrides.claudeCode`
- Appends `prompt` as markdown body

**Settings → `settings.json`:**
- Permissions in `allow`/`deny`/`ask` arrays (e.g., `"Bash(git diff *)"`)
- Model overrides, env configuration

**MCP → `.mcp.json`:**
- Local: `{command, args, env}`, Remote: `{url, headers}`

**CLAUDE.md → same content as AGENTS.md**

### Codex Generator (`lib/generators/codex.nix`)

**Best-effort mapping:**
- Agent → markdown files (limited frontmatter)
- `AGENTS.md` → same content as OpenCode
- Skills/MCP → whatever Codex supports at implementation time

---

## Wrapper Strategy

### OpenCode (excellent Nix compatibility)

```nix
makeWrapper ${pkgs.opencode}/bin/opencode $out/bin/opencode \
  --set OPENCODE_CONFIG "${agentSystem}/opencode.json" \
  --set OPENCODE_CONFIG_DIR "${agentSystem}" \
  --set OPENCODE_CONFIG_CONTENT '{"autoupdate":false}'
```

- Full env var support: `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR` redirect config completely
- Writable state stays in `~/.config/opencode/` (sessions, cache) — no conflict
- Auth: `{env:ANTHROPIC_API_KEY}` in config, resolved at runtime

### Claude Code (requires symlink strategy)

```bash
# Wrapper script
CLAUDE_HOME="$HOME/.claude"
mkdir -p "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills"

# Symlink read-only agent/skill definitions from Nix store
for f in ${agentSystem}/agents/*.md; do
  ln -sf "$f" "$CLAUDE_HOME/agents/$(basename "$f")"
done
for d in ${agentSystem}/skills/*/; do
  ln -sfn "$d" "$CLAUDE_HOME/skills/$(basename "$d")"
done

# Copy CLAUDE.md to user home
cp -f ${agentSystem}/CLAUDE.md "$CLAUDE_HOME/CLAUDE.md"

exec ${pkgs.claude-code}/bin/claude "$@"
```

- Writable state (history, todos, MEMORY.md) stays in `~/.claude/` — untouched
- Auth: `apiKeyHelper` script or env vars
- Compatibility: moderate — requires careful symlink management

### Codex

```bash
export CODEX_HOME="$HOME/.codex"
mkdir -p "$CODEX_HOME"
ln -sf ${agentSystem}/AGENTS.md "$CODEX_HOME/AGENTS.md"
exec ${pkgs.codex}/bin/codex "$@"
```

---

## Flake Outputs

```nix
{
  lib = {
    mkAgentSystem   # Evaluate modules and build config directory
    mkWrappedTool   # Wrap tool binary with generated configs
    types           # Type definitions for consumers
  };

  packages.${system} = {
    opencode          # OpenCode wrapped with default agent team
    claude-code       # Claude Code wrapped with default agent team
    codex             # Codex wrapped with default agent team
    opencode-config   # Just the config directory (no wrapping)
    claude-code-config
    codex-config
  };

  devShells.${system}.default  # All wrapped tools + dev dependencies

  templates.default = {
    description = "Custom agent team using nix-agents";
    path = ./templates/default;
  };

  checks.${system} = {
    agent-graph   # Validates graph integrity
    config-gen    # Ensures all configs generate without error
    format        # nixfmt check
    lint          # statix check
  };

  presets.default  # The pre-composed 8-agent team (importable module)
}
```

---

## Consumer Usage

### Standalone (`nix run`)

```bash
nix run github:kirksw/nix-agents#opencode
nix run github:kirksw/nix-agents#claude-code
nix run github:kirksw/nix-agents#codex
```

### Direnv

```bash
# .envrc
use flake github:kirksw/nix-agents
```

### Custom Agent Team (importing the flake)

```nix
{
  inputs.nix-agents.url = "github:kirksw/nix-agents";

  outputs = { nix-agents, nixpkgs, ... }:
  let
    inherit (nix-agents.lib) mkAgentSystem mkWrappedTool;
    pkgs = nixpkgs.legacyPackages.aarch64-darwin;

    mySystem = mkAgentSystem {
      imports = [
        nix-agents.presets.default    # Default 8-agent team
        ./agents/my-custom-agent.nix  # Add custom agent
      ];
      # Override an existing agent
      agents.code-monkey.model = "anthropic/claude-opus-4-6";
      # Add a custom MCP server
      mcpServers.my-server = {
        type = "remote";
        url = "https://my-api.example.com/mcp";
      };
    };
  in {
    packages.aarch64-darwin.opencode = mkWrappedTool {
      tool = pkgs.opencode;
      agentSystem = mySystem;
      target = "opencode";
    };
  };
}
```

---

## Example Agent Definition

```nix
# agents/the-architect.nix
{ lib, ... }:
{
  agents.the-architect = {
    description = "Designs system architecture, API boundaries, and implementation plans.";
    mode = "subagent";
    model = "openai/gpt-5.2";
    temperature = 0.2;
    reasoningEffort = "xhigh";

    delegatesTo = [ "chaos-demon" "explore" ];

    permissions = {
      edit = {
        default = "deny";
        rules = {
          "*.md" = "allow";
          "*.mdx" = "allow";
          "*.markdown" = "allow";
        };
      };
      bash = "deny";
      task = {
        default = "deny";
        rules = {
          "chaos-demon" = "allow";
          "explore" = "allow";
        };
      };
    };

    skills = [ "swe-pruner-mcp" ];

    prompt = ''
      You are a principal architect focused on long-term system quality.

      Tools:
      - Use MCP tools `read_pruned` and `search_pruned` for efficient context-aware
        code reading and searching.

      Priorities:
      - Define clear module and service boundaries.
      - Evaluate tradeoffs across correctness, scalability, reliability, and cost.
      - Reduce complexity and operational risk.
      - Produce phased plans that teams can execute safely.

      When answering:
      - Start with assumptions and constraints.
      - Compare 2-3 viable options and recommend one with rationale.
      - Call out migration strategy, rollback path, and observability impacts.
      - Include key risks and how to mitigate them.

      Be concise, concrete, and implementation-aware.
    '';

    orchestration.patterns = {
      "Plan then execute" = ''
        For complex features, send the problem to `the-architect` first. Take its
        plan and hand it to `code-monkey` for implementation. If the plan is flawed,
        `code-monkey` can escalate to `10xBEAST` who will challenge `the-architect`
        and force a corrected plan.
      '';
    };

    orchestration.antiPatterns = [
      "Do not use `the-architect` for implementation — it is intentionally restricted to design output."
    ];
  };
}
```

---

## Implementation Phases

### Phase 1: Core Types + OpenCode Generator + Graph Validation + AGENTS.md

**Combined MVP.** Builds the foundation and produces working OpenCode configs.

| Task | Description | Files | Acceptance |
|------|-------------|-------|------------|
| **P1-T1** Create flake scaffold | Init flake with nixpkgs input, lib/packages/devShells/checks outputs. Use flake-utils or flake-parts for multi-system. | `flake.nix` | `nix flake check --no-build` passes. `nix flake show` displays expected outputs. |
| **P1-T2** Define core type system | Implement NixOS-style option types for agent, skill, mcp-server, permission. Use `lib.types.submodule` for nested structures. | `lib/types.nix` | Types catch invalid values (wrong enum, missing required field). |
| **P1-T3** Implement module evaluation | Create `lib.evalModules` wrapper. Define module interfaces for agent, skill, mcp-server, system. System module composes sub-modules. | `lib/eval.nix`, `modules/agent.nix`, `modules/skill.nix`, `modules/mcp-server.nix`, `modules/system.nix` | Can evaluate a minimal system with one agent. Options type-checked. |
| **P1-T4** Port agents to Nix | Convert all 8 agents from `~/.config/opencode/agents/*.md` to Nix modules. Include orchestration patterns from current `AGENTS.md`. | `agents/*.nix` (8 files) | Each agent evaluates without error. All fields represented. Source: `~/.config/opencode/agents/*.md` |
| **P1-T5** Implement graph validation | Add assertions to `system.nix`: delegatesTo targets exist, no self-delegation, task permissions reference existing agents, skill/MCP refs valid, reachability warnings. | `modules/system.nix` | `delegatesTo = ["nonexistent"]` fails with clear error. All 7 assertion types tested. |
| **P1-T6** Implement OpenCode generator | Transform evaluated agents to OpenCode format: YAML frontmatter + markdown body. Map permissions to glob rules. Generate MCP entries in `opencode.json`. | `lib/generators/opencode.nix` | Generated `agents/*.md` semantically match current `~/.config/opencode/agents/*.md`. Source: current configs. |
| **P1-T7** Implement AGENTS.md generator | Collect `orchestration.patterns` and `antiPatterns` across agents. Generate sections: header, delegation, patterns, decomposition, context, anti-patterns. Default prose for edges without explicit patterns. | `lib/generators/agents-md.nix` | Generated AGENTS.md semantically matches `~/.config/opencode/AGENTS.md`. |
| **P1-T8** Implement `mkAgentSystem` | Builder that takes module list, evaluates via `eval.nix`, calls generator, produces config directory derivation. Initial support: `target = "opencode"`. | `lib/builders.nix` | `nix build .#opencode-config` produces store path with `agents/*.md`, `AGENTS.md`, `opencode.json`. |
| **P1-T9** Create default preset | Import all 8 agents. This is the pre-composed team. | `presets/default.nix` | Importing preset + building produces full agent team config. |
| **P1-T10** Wire flake outputs | Connect lib, packages (`opencode-config`), checks (`agent-graph`, `format`). | `flake.nix` | `nix build .#opencode-config` works. `nix flake check` passes. |

### Phase 2: Claude Code Generator + Wrapper Scripts

**Depends on:** Phase 1

| Task | Description | Files | Acceptance |
|------|-------------|-------|------------|
| **P2-T1** Claude Code generator | Transform agents to Claude Code format: frontmatter, `allow`/`deny`/`ask` permissions, `.mcp.json`, `CLAUDE.md`. | `lib/generators/claude-code.nix` | Valid Claude Code config. Permissions correctly mapped. |
| **P2-T2** OpenCode wrapper (`mkWrappedTool`) | Use `makeWrapper` to set `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `OPENCODE_CONFIG_CONTENT`. Disable autoupdate. | `lib/builders.nix` | `nix run .#opencode` launches with generated config. Auth via `ANTHROPIC_API_KEY`. |
| **P2-T3** Claude Code wrapper | Wrapper script with symlinks for read-only agents/skills. Preserve writable state. Handle `CLAUDE.md` placement. | `lib/builders.nix` | `nix run .#claude-code` launches with generated agents. Writable `~/.claude/` preserved. |
| **P2-T4** Add devShell | Include both wrapped tools + dev dependencies (nixfmt, statix, deadnix). | `flake.nix` | `nix develop` provides `opencode` and `claude` commands. |

### Phase 3: Skills + MCP Server Management

**Depends on:** Phase 1

| Task | Description | Files | Acceptance |
|------|-------------|-------|------------|
| **P3-T1** Port skills to Nix | Convert 5 skills. Support `content`-based and `src`-based modes. Skill-creator has bundled resources. | `skills/*.nix` (5 files) | Skills generate correct `SKILL.md` for both tool formats. Source: `~/.config/opencode/skills/` |
| **P3-T2** MCP server module | `swe-pruner.nix` as reference. Optional `package` attribute injects nix store path. Update generators for MCP output. | `mcp-servers/swe-pruner.nix`, generators | `swe-pruner` appears in `opencode.json` and `.mcp.json` with correct paths. |
| **P3-T3** Update default preset | Include all skills and MCP servers. Update agent `skills` references. | `presets/default.nix`, `agents/*.nix` | Full config output includes skills directories and MCP entries. |

### Phase 4: Codex + Templates + CI

**Depends on:** Phase 2, Phase 3

| Task | Description | Files | Acceptance |
|------|-------------|-------|------------|
| **P4-T1** Codex generator + wrapper | Best-effort mapping. `AGENTS.md` + agent markdown. Wrapper with `CODEX_HOME`. | `lib/generators/codex.nix`, `lib/builders.nix` | `nix run .#codex` launches with generated agents. |
| **P4-T2** Consumer template | Template flake showing: import preset, add custom agent, override model, add MCP server. | `templates/default/` | `nix flake init -t github:kirksw/nix-agents` creates working project. |
| **P4-T3** Flake checks | `agent-graph` (assertions), `config-gen` (all 3 outputs), `format` (nixfmt), `lint` (statix). | `flake.nix` | `nix flake check` passes. Broken configs fail with clear errors. |
| **P4-T4** Documentation | `ARCHITECTURE.md` with Mermaid diagrams, `README.md` rewrite, API reference, type reference. | `ARCHITECTURE.md`, `README.md` | New user can understand and use the project from docs. |

---

## Conventions

### Nix Style
- 2-space indentation, trailing commas
- Format: `nixfmt`, Lint: `statix`, Dead code: `deadnix`
- Option naming: `camelCase` (e.g., `mcpServers`, `delegatesTo`)
- Module pattern: `{lib, config, pkgs, ...}: { options = ...; config = ...; }`

### Commits
- Format: `type: description` (e.g., `feat(opencode): add generator`)
- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
- One logical change per commit

### Testing
- `nix flake check` — assertions + builds
- `nixfmt --check **/*.nix` — formatting
- `statix check` — linting
- Diff generated output against current hand-authored configs

---

## Risks

| Risk | Area | Mitigation |
|------|------|------------|
| Claude Code symlinks are fragile | Wrapper | Pin Claude Code version. Integration test verifies wrapper with pinned version. Monitor releases. |
| AGENTS.md generation lacks nuance | Generation | Override system for hand-authored prose. Compare LLM behavior. Iterate on default templates. |
| Permission granularity loss across tools | Permissions | Per-tool overrides escape hatch. Generator warns on dropped rules. E2E permission testing. |
| Codex config surface is limited/changing | Codex | Extension points in generator. Accept Codex may lag. Monitor releases. |
| Accidental secret leak in Nix store | Security | Never accept secret values in options. Use `{env:VAR}` placeholders. Build-time validation. Document security model. |

---

## Source of Truth References

These are the current hand-authored configs that the generated output must match:

### Agents (target output format for OpenCode)
- `~/.config/opencode/agents/code-monkey.md`
- `~/.config/opencode/agents/the-architect.md`
- `~/.config/opencode/agents/10xBEAST.md`
- `~/.config/opencode/agents/bottleneck.md`
- `~/.config/opencode/agents/chaos-demon.md`
- `~/.config/opencode/agents/code-red.md`
- `~/.config/opencode/agents/scribe.md`
- `~/.config/opencode/agents/explore.md`

### Orchestration (target output for AGENTS.md)
- `~/.config/opencode/AGENTS.md`

### Skills (target output format)
- `~/.config/opencode/skills/swe-pruner-mcp/SKILL.md`
- `~/.config/opencode/skills/nix-coding-style/SKILL.md`
- `~/.config/opencode/skills/nix-flake-ops/SKILL.md`
- `~/.config/opencode/skills/nix-module-workflow/SKILL.md`
- `~/.config/opencode/skills/skill-creator/`

### MCP Config (target JSON format)
- `~/.config/opencode/opencode.json` (MCP section)

### Claude Code (target output format)
- `~/.claude/CLAUDE.md`
- `~/.claude/skills/nix-coding-style/SKILL.md`
