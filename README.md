# nix-agents

Composable LLM agent teams as Nix derivations. Define your agent graph once, generate configs for OpenCode, Claude Code, Codex, and Pi from a single source of truth.

## Quick start

### Use the default agent team

```bash
# Run with generated configs
nix run github:kirksw/nix-agents#opencode
nix run github:kirksw/nix-agents#claude
nix run github:kirksw/nix-agents#codex
nix run github:kirksw/nix-agents#pi

# Build config directories only
nix build github:kirksw/nix-agents#opencode-config
nix build github:kirksw/nix-agents#claude-config
nix build github:kirksw/nix-agents#codex-config
nix build github:kirksw/nix-agents#pi-config
```

### Create a custom agent team

```bash
nix flake init -t github:kirksw/nix-agents
```

This scaffolds a flake that imports the default preset and lets you add agents, override models, or attach MCP servers:

```nix
{
  inputs.nix-agents.url = "github:kirksw/nix-agents";

  outputs = { nix-agents, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        agentsLib = nix-agents.lib.${system};

        mySystem = agentsLib.mkAgentSystem {
          inherit pkgs;
          modules = [
            nix-agents.presets.default
            ./defs/agents/my-agent.nix
            { agents.code-monkey.model = "anthropic/claude-opus-4-6"; }
          ];
          target = "opencode";
        };
      in {
        packages.opencode = agentsLib.mkWrappedTool {
          inherit pkgs;
          target = "opencode";
          tool = "opencode";
          agentSystem = mySystem;
        };
      }
    );
}
```

`mkWrappedTool` also accepts `profile = "<name>"` to force a specific runtime profile namespace.
When a profile is selected or forced, generated agent assets are projected into
`~/.config/nix-agents/<tool>/profiles/<profile>`. Tools that keep native runtime state, such as
OpenCode and Pi, still keep their own tool-specific XDG profile directories alongside that
canonical `nix-agents` asset root.

### Run a self-hosted Multica server

The flake packages the Multica CLI and a `multica-selfhost` helper pinned to the same upstream release.
The helper mirrors Multica's installer flow: it creates `~/.multica/server/.env`, generates `JWT_SECRET`,
and starts the official Docker Compose stack.

```bash
nix run .#multica-selfhost
nix run .#multica-selfhost -- setup-cli
```

The web UI starts at <http://localhost:3000> and the backend at <http://localhost:8080>. Use
`MULTICA_INSTALL_DIR` to keep server state somewhere other than `~/.multica/server`.

## Built-in agents

| Agent | Mode | Role |
|-------|------|------|
| `code-monkey` | primary | Implementation lead |
| `the-architect` | subagent | System design and planning |
| `10xBEAST` | subagent | Red-team reviewer |
| `bottleneck` | subagent | Process friction analysis |
| `chaos-demon` | subagent | Failure mode analysis |
| `code-red` | subagent | Urgent triage |
| `scribe` | subagent | Documentation and handoffs |
| `explore` | subagent | Scope and dependency exploration |

## Built-in skills

| Skill | Description |
|-------|-------------|
| `swe-pruner-mcp` | Compact code scanning via MCP tools |
| `nix-agents` | Nix-agents coding style, module workflow, and flake operations |
| `system-context` | Local machine and nix-agents source-of-truth context |
| `skill-creator` | Recipe for creating new skills |

## Observability

`agent-observe` tracks session activity, token usage, and delegation events in a local SQLite database.

```bash
# Start the HTTP service (localhost:7734)
nix run .#observe -- serve

# Query from the CLI
nix run .#observe -- summary
nix run .#observe -- sessions --since 2026-03-01
nix run .#observe -- sessions --project nix-agents --limit 10

# Start the MCP server (stdio, for agents to query directly)
nix run .#observe -- mcp

# Import a session JSON file written by the session-write hooks
nix run .#observe -- ingest ~/.local/share/nix-agents/sessions/personal/nix-agents/2026-03-15T10-00-00.json
```

Session files are written automatically to `~/.local/share/nix-agents/sessions/<profile>/<project>/` when you use the session-write hooks (see `defs/hooks/session-write.nix`).

## Development

```bash
nix develop  # nixfmt, statix, deadnix

nix flake check        # Run all checks
nix flake show         # List outputs
```

### Checks

| Check | What it does |
|-------|--------------|
| `agent-graph` | Validates delegation graph integrity |
| `config-gen-opencode` | Builds OpenCode config |
| `config-gen-claude` | Builds Claude Code config |
| `config-gen-codex` | Builds Codex config |
| `config-gen-cursor` | Builds Cursor rules config |
| `config-gen-amp` | Builds Amp config |
| `config-gen-pi` | Builds Pi config |
| `schema-compat-claude` | Validates Claude settings.json schema |
| `schema-compat-opencode` | Validates OpenCode config schema |
| `schema-compat-session` | Validates session file schema |
| `observe-service-build` | Verifies agent-observe binary builds |
| `format` | nixfmt formatting check |
| `lint` | statix lint check |

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for type reference, data flow diagrams, and the delegation graph.

## License

See [LICENSE](./LICENSE).
