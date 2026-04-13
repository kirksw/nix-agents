# Nix-Agents Flake Operations

## Supported Targets

| Target | Package | Wrapped binary |
|--------|---------|----------------|
| opencode | `opencode-config` | `opencode` |
| claude | `claude-config` | `claude` |
| codex | `codex-config` | `codex` |
| cursor | `cursor-config` | none |
| amp | `amp-config` | none |
| pi | `pi-config` | none |

## Common Commands

```bash
nix build .#opencode-config
nix build .#claude-config

nix run .#opencode
nix run .#claude
nix run .#codex

nix run .#sync
nix run .#graph
nix flake check
nix run .#fmt
nix run .#lint
nix run .#bench
nix develop
```

## Check Suite

`nix flake check` runs:

- `config-gen-*`
- `schema-compat-*`
- `wrapper-smoke-*`
- `eval-*`
- `format`
- `lint`

## Workflow After Any Change

After modifying `lib/`, `modules/`, `defs/`, `targets/`, or `lib/generators/`:

1. `nix build .#opencode-config`
2. `nix build .#claude-config`
3. `nix flake check`

## Using `nix-agents` In Your Own Flake

```nix
inputs.nix-agents.url = "github:kirksw/nix-agents";

packages.my-config = nix-agents.lib.${system}.mkAgentSystem {
  inherit pkgs;
  modules = [ nix-agents.presets.default ./my-agent.nix ];
  target = "opencode";
};
```

## Initialize From Template

```bash
nix flake init -t github:kirksw/nix-agents
```

## Guardrails

- Run `nix flake check` before committing
- Do not edit the `result` symlink from `nix build`
- `cursor` and `amp` outputs may still evolve
