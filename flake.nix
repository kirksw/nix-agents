{
  description = "Composable LLM agents as Nix derivations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      llm-agents,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        agentPkgs = llm-agents.packages.${system};
        library = import ./lib/default.nix { inherit (pkgs) lib; };
        defaultModules = [ ./presets/default.nix ];

        mkConfig =
          target:
          library.mkAgentSystem {
            inherit pkgs target;
            modules = defaultModules;
          };

        opencodeConfig = mkConfig "opencode";
        claudeConfig = mkConfig "claude";
        codexConfig = mkConfig "codex";

        piCodingAgent = pkgs.callPackage ./packages/pi-coding-agent { };

        nixFiles = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = pkgs.lib.fileset.fileFilter (f: f.hasExt "nix") ./.;
        };

        syncAgents = pkgs.writeShellScriptBin "sync-agents" ''
          set -euo pipefail

          sync_tree() {
            source_dir="$1"
            target_dir="$2"

            ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
            ${pkgs.coreutils}/bin/chmod -R u+w "$target_dir" 2>/dev/null || true
            ${pkgs.coreutils}/bin/rm -rf \
              "$target_dir"/* \
              "$target_dir"/.[!.]* \
              "$target_dir"/..?* \
              2>/dev/null || true
            ${pkgs.coreutils}/bin/cp -R "$source_dir"/. "$target_dir"/
          }

          CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}"
          DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}"

          # OpenCode
          if [ -d "${opencodeConfig}" ]; then
            echo "Syncing OpenCode to $CONFIG_DIR/opencode..."
            sync_tree "${opencodeConfig}/agents" "$CONFIG_DIR/opencode/agents"
            sync_tree "${opencodeConfig}/skills" "$CONFIG_DIR/opencode/skills"
            ${pkgs.coreutils}/bin/cp "${opencodeConfig}/AGENTS.md" "$CONFIG_DIR/opencode/AGENTS.md" 2>/dev/null || true
            ${pkgs.coreutils}/bin/cp "${opencodeConfig}/opencode.json" "$CONFIG_DIR/opencode/opencode.json" 2>/dev/null || true
          fi

          # Claude
          if [ -d "${claudeConfig}" ]; then
            echo "Syncing Claude to $DATA_DIR/nix-agents/claude..."
            sync_tree "${claudeConfig}/agents" "$DATA_DIR/nix-agents/claude/agents"
            sync_tree "${claudeConfig}/skills" "$DATA_DIR/nix-agents/claude/skills"
            ${pkgs.coreutils}/bin/cp "${claudeConfig}/CLAUDE.md" "$DATA_DIR/nix-agents/claude/CLAUDE.md" 2>/dev/null || true
            ${pkgs.coreutils}/bin/cp "${claudeConfig}/settings.json" "$DATA_DIR/nix-agents/claude/settings.json" 2>/dev/null || true
            ${pkgs.coreutils}/bin/cp "${claudeConfig}/.mcp.json" "$DATA_DIR/nix-agents/claude/.mcp.json" 2>/dev/null || true
          fi

          # Codex
          if [ -d "${codexConfig}" ]; then
            echo "Syncing Codex to $DATA_DIR/nix-agents/codex..."
            sync_tree "${codexConfig}/agents" "$DATA_DIR/nix-agents/codex/agents"
            sync_tree "${codexConfig}/skills" "$DATA_DIR/nix-agents/codex/skills"
            ${pkgs.coreutils}/bin/cp "${codexConfig}/AGENTS.md" "$DATA_DIR/nix-agents/codex/AGENTS.md" 2>/dev/null || true
          fi

          echo "Done!"
        '';
      in
      {
        lib = {
          inherit (library) evalModules types;
          inherit (library) mkAgentSystem mkWrappedTool;
        };

        packages = {
          opencode-config = opencodeConfig;
          claude-config = claudeConfig;
          codex-config = codexConfig;
          opencode = library.mkWrappedTool {
            inherit pkgs;
            target = "opencode";
            tool = agentPkgs.opencode;
            agentSystem = opencodeConfig;
          };
          claude = library.mkWrappedTool {
            inherit pkgs;
            target = "claude";
            tool = agentPkgs.claude-code;
            agentSystem = claudeConfig;
          };
          codex = library.mkWrappedTool {
            inherit pkgs;
            target = "codex";
            tool = agentPkgs.codex;
            agentSystem = codexConfig;
          };
          pi-coding-agent = piCodingAgent;
          default = opencodeConfig;
        };

        apps = {
          sync = {
            type = "app";
            program = "${syncAgents}/bin/sync-agents";
            meta.description = "Sync agent configs to local config directories";
          };
        };

        devShells.default = pkgs.mkShell {
          name = "nix-agents";
          packages = with pkgs; [
            nixfmt-rfc-style
            statix
            deadnix
          ];
        };

        checks = {
          agent-graph = opencodeConfig;

          config-gen-opencode = opencodeConfig;
          config-gen-claude = claudeConfig;
          config-gen-codex = codexConfig;

          format =
            pkgs.runCommand "check-format"
              {
                nativeBuildInputs = [
                  pkgs.nixfmt-rfc-style
                  pkgs.findutils
                ];
              }
              ''
                find ${nixFiles} -name '*.nix' -exec nixfmt --check {} +
                touch $out
              '';

          lint = pkgs.runCommand "check-lint" { nativeBuildInputs = [ pkgs.statix ]; } ''
            statix check ${nixFiles} 2>&1
            touch $out
          '';
        };
      }
    )
    // {
      overlays.default = final: prev: {
        pi-coding-agent = final.callPackage ./packages/pi-coding-agent { };
      };

      templates.default = {
        description = "Custom agent team using nix-agents";
        path = ./templates/default;
      };
    };
}
