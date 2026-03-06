# nix-agents

Composable LLM agent teams as Nix derivations. Define your agent graph once, generate configs for OpenCode, Claude Code, and Codex from a single source of truth.

## Quick start

### Use the default agent team

```bash
# Run with generated configs
nix run github:kirksw/nix-agents#opencode
nix run github:kirksw/nix-agents#claude
nix run github:kirksw/nix-agents#codex

# Build config directories only
nix build github:kirksw/nix-agents#opencode-config
nix build github:kirksw/nix-agents#claude-config
nix build github:kirksw/nix-agents#codex-config
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
            ./agents/my-agent.nix
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
| `nix-coding-style` | Nix formatting and style conventions |
| `nix-flake-ops` | Flake composition patterns |
| `nix-module-workflow` | Composable Nix module patterns |
| `skill-creator` | Recipe for creating new skills |

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
| `format` | nixfmt formatting check |
| `lint` | statix lint check |

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for type reference, data flow diagrams, and the delegation graph.

## License

See [LICENSE](./LICENSE).
