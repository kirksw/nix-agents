{
  skills.nix-flake-ops = {
    description = "Build, validate, and sync nix-agents configurations. Use when running checks, building configs for a target tool, syncing to local config dirs, or operating the flake development workflow.";
    content = ''
      # Nix-Agents Flake Operations

      ## Supported Targets

      | Target   | Package           | Wrapped binary |
      |----------|-------------------|----------------|
      | opencode | `opencode-config` | `opencode`     |
      | claude   | `claude-config`   | `claude`       |
      | codex    | `codex-config`    | `codex`        |
      | cursor   | `cursor-config`   | —              |
      | amp      | `amp-config`      | —              |
      | pi       | `pi-config`       | —              |

      ## Common Commands

      ```bash
      # Build a config derivation
      nix build .#opencode-config
      nix build .#claude-config

      # Run a wrapped tool directly (uses built configs)
      nix run .#opencode
      nix run .#claude
      nix run .#codex

      # Sync all configs to local tool config dirs
      nix run .#sync

      # Print the agent delegation graph (Mermaid)
      nix run .#graph

      # Run all checks
      nix flake check

      # Format all .nix files
      nix run .#fmt

      # Lint (statix + deadnix)
      nix run .#lint

      # Run structural eval suite
      nix run .#bench

      # Dev shell (nixfmt-rfc-style, statix, deadnix)
      nix develop
      ```

      ## Check Suite

      `nix flake check` runs:
      - `config-gen-*` — builds each target config derivation
      - `schema-compat-*` — validates generated JSON against schemas
      - `wrapper-smoke-*` — checks wrapper shell syntax and key files
      - `eval-*` — structural correctness assertions
      - `format` — nixfmt-rfc-style check
      - `lint` — statix lint check

      ## Workflow: After Any Change

      After modifying `lib/`, `modules/`, `defs/`, `targets/`, or `lib/generators/`:

      1. `nix build .#opencode-config` — verify OpenCode config generation
      2. `nix build .#claude-config` — verify Claude config generation
      3. `nix flake check` — run all checks

      ## Using nix-agents in Your Own Flake

      ```nix
      inputs.nix-agents.url = "github:kirksw/nix-agents";

      # in outputs:
      packages.my-config = nix-agents.lib.''${system}.mkAgentSystem {
        inherit pkgs;
        modules = [ nix-agents.presets.default ./my-agent.nix ];
        target = "opencode";
      };
      ```

      ## Initialise from Template

      ```bash
      nix flake init -t github:kirksw/nix-agents
      ```

      ## Guardrails

      - Run `nix flake check` before committing.
      - Do not edit the `result` symlink produced by `nix build`.
      - `cursor` and `amp` generator output format may still evolve — check EXPERIMENTAL marker in outputs.
    '';
    resources = { };
    src = null;
  };
}
