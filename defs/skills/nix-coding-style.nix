{
  skills.nix-coding-style = {
    description = "Nix code formatting and style conventions for nix-agents. Use when writing or reviewing Nix code in this repository.";
    content = ''
      # Nix Coding Style

      Follow these conventions when writing Nix code in this repository.

      ## Formatting

      - Use 2-space indentation
      - Use `nixfmt-rfc-style` (not plain `nixfmt`) — the RFC style formatter
      - Format all `.nix` files before committing: `nix run .#fmt`
      - Check format without modifying: `nixfmt --check <file>`

      ## Linting

      ```bash
      nix run .#lint   # statix + deadnix
      statix check .   # anti-pattern detection
      deadnix --fail . # unused binding detection
      ```

      ## Module Pattern (defs/ files)

      Agent, skill, and MCP defs are plain attrsets — no `{ config, lib, ... }:` boilerplate
      unless the file genuinely needs specialArgs:

      ```nix
      # defs/agents/my-agent.nix
      {
        agents.my-agent = {
          description = "…";
          model = "balanced";
          prompt = "Implement the task.";
        };
      }
      ```

      ## Module Pattern (modules/ files)

      Module declarations use NixOS-style options:

      ```nix
      # modules/my-module.nix
      { lib, types, ... }:
      {
        options.myOption = lib.mkOption {
          type = types.str;
          default = "";
          description = "…";
        };
      }
      ```

      ## Config Generation Pattern

      Generators produce JSON/YAML strings via `builtins.toJSON`:

      ```nix
      builtins.toJSON {
        agents = lib.mapAttrsToList (name: agent: { inherit name; … }) config.agents;
      }
      ```

      ## Option Naming

      - Use kebab-case for agent/skill/mcp names: `agents.my-agent`, `skills.nix-flake-ops`
      - Use camelCase for Nix option paths: `options.tierMapping`, `options.mcpServers`

      ## Common Patterns

      ### Optional attribute inclusion
      ```nix
      { required = "value"; }
      // lib.optionalAttrs (condition) { optional = "value"; }
      ```

      ### Filtering attrsets
      ```nix
      lib.filterAttrs (name: _: builtins.elem name whitelist) attrset
      ```

      ### Mapping attrsets to lists
      ```nix
      lib.mapAttrsToList (name: value: { inherit name; … }) attrset
      ```

      ## Testing

      Run before committing:
      ```bash
      nix run .#fmt     # format all .nix files
      nix run .#lint    # statix + deadnix
      nix flake check   # full check suite
      ```
    '';
    resources = { };
    src = null;
  };
}
