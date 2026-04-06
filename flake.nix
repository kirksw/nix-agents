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

        mkConfigWithSrc =
          target:
          library.mkAgentSystem {
            inherit pkgs target;
            modules = defaultModules;
            src = ./.;
          };

        opencodeConfig = mkConfigWithSrc "opencode";
        claudeConfig = mkConfig "claude";
        codexConfig = mkConfig "codex";
        piConfig = mkConfigWithSrc "pi";
        cursorConfig = mkConfig "cursor";
        ampConfig = mkConfig "amp";

        piCodingAgent = pkgs.callPackage ./targets/pi/package { };

        updateScript = pkgs.writeShellApplication {
          name = "update";
          runtimeInputs = [
            pkgs.curl
            pkgs.jq
            pkgs.git
            pkgs.nix
          ];
          text = builtins.readFile ./lib/updater/update.sh;
        };

        nixFiles = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = pkgs.lib.fileset.fileFilter (f: f.hasExt "nix") ./.;
        };

        evaluatedConfig = library.evalModules { modules = defaultModules; };
        mermaidGenerator = import ./lib/generators/mermaid.nix { inherit (pkgs) lib; };
        mermaidOutput = mermaidGenerator { inherit (evaluatedConfig.config) agents; };

        graphScript = pkgs.writeShellScriptBin "graph" ''
          cat <<'MERMAID'
          ${mermaidOutput}
          MERMAID
        '';

        evals = import ./checks/evals.nix {
          inherit
            pkgs
            opencodeConfig
            claudeConfig
            codexConfig
            ampConfig
            ;
        };

        evalCheckNames = builtins.attrNames evals;

        benchScript = pkgs.writeShellScriptBin "bench" ''
          set -euo pipefail
          echo "Running eval suite..."
          nix build ${pkgs.lib.concatStringsSep " " (map (name: ".#checks.${system}.${name}") evalCheckNames)}
          echo "All evals passed."
        '';

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

          # Pi
          if [ -d "${piConfig}" ]; then
            echo "Syncing Pi to $HOME/.pi/agent..."
            sync_tree "${piConfig}/agents" "$HOME/.pi/agent/agents"
            sync_tree "${piConfig}/skills" "$HOME/.pi/agent/skills"
            ${pkgs.coreutils}/bin/cp "${piConfig}/AGENTS.md" "$HOME/.pi/agent/AGENTS.md" 2>/dev/null || true
            if [ -d "${piConfig}/extensions" ]; then
              sync_tree "${piConfig}/extensions" "$HOME/.pi/agent/extensions"
            fi
            if [ -d "${piConfig}/prompts" ]; then
              sync_tree "${piConfig}/prompts" "$HOME/.pi/agent/prompts"
            fi
          fi

          # Cursor
          if [ -d "${cursorConfig}" ]; then
            echo "Syncing Cursor to $HOME/.cursor..."
            ${pkgs.coreutils}/bin/mkdir -p "$HOME/.cursor/rules"
            if [ -d "${cursorConfig}/.cursor/rules" ]; then
              sync_tree "${cursorConfig}/.cursor/rules" "$HOME/.cursor/rules"
            fi
            ${pkgs.coreutils}/bin/cp "${cursorConfig}/.cursor/mcp.json" "$HOME/.cursor/mcp.json" 2>/dev/null || true
          fi

          # Amp
          if [ -d "${ampConfig}" ]; then
            echo "Syncing Amp to $CONFIG_DIR/amp..."
            sync_tree "${ampConfig}/agents" "$CONFIG_DIR/amp/agents"
            sync_tree "${ampConfig}/skills" "$CONFIG_DIR/amp/skills"
            ${pkgs.coreutils}/bin/cp "${ampConfig}/AGENTS.md" "$CONFIG_DIR/amp/AGENTS.md" 2>/dev/null || true
            ${pkgs.coreutils}/bin/cp "${ampConfig}/amp.json" "$CONFIG_DIR/amp/amp.json" 2>/dev/null || true
          fi

          echo "Done!"
        '';
      in
      {
        lib = {
          inherit (library) evalModules types;
          inherit (library) mkAgentSystem mkProfileMeta mkWrappedTool;
        };

        packages = {
          opencode-config = opencodeConfig;
          claude-config = claudeConfig;
          codex-config = codexConfig;
          pi-config = piConfig;
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
          cursor-config = cursorConfig;
          amp-config = ampConfig;
          pi-coding-agent = piCodingAgent;
          update-script = updateScript;
          observe-service = pkgs.callPackage ./services/agent-observe { };
          default = opencodeConfig;
        };

        apps = {
          sync = {
            type = "app";
            program = "${syncAgents}/bin/sync-agents";
            meta.description = "Sync agent configs to local config directories";
          };
          graph = {
            type = "app";
            program = "${graphScript}/bin/graph";
          };
          bench = {
            type = "app";
            program = "${benchScript}/bin/bench";
          };
          observe = {
            type = "app";
            program = "${self.packages.${system}.observe-service}/bin/agent-observe";
          };
          update = {
            type = "app";
            program = "${self.packages.${system}.update-script}/bin/update";
          };
          fmt = {
            type = "app";
            program = "${pkgs.writeShellScriptBin "fmt" ''
              set -euo pipefail
              find . -name '*.nix' -not -path '*/result/*' -exec ${pkgs.nixfmt-rfc-style}/bin/nixfmt {} +
            ''}/bin/fmt";
          };
          lint = {
            type = "app";
            program = "${pkgs.writeShellScriptBin "lint" ''
              set -euo pipefail
              echo "==> statix"
              ${pkgs.statix}/bin/statix check .
              echo "==> deadnix"
              ${pkgs.deadnix}/bin/deadnix --fail .
            ''}/bin/lint";
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
          config-gen-cursor = cursorConfig;
          config-gen-amp = ampConfig;

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

          config-gen-pi = piConfig;

          schema-compat-claude =
            pkgs.runCommand "schema-compat-claude"
              {
                nativeBuildInputs = [ pkgs.check-jsonschema ];
              }
              ''
                check-jsonschema \
                  --schemafile ${./lib/schemas/claude-code-settings.json} \
                  ${claudeConfig}/settings.json
                touch $out
              '';

          schema-compat-opencode =
            pkgs.runCommand "schema-compat-opencode"
              {
                nativeBuildInputs = [ pkgs.check-jsonschema ];
              }
              ''
                check-jsonschema \
                  --schemafile ${./lib/schemas/opencode-config.json} \
                  ${opencodeConfig}/opencode.json
                touch $out
              '';

          wrapper-smoke-opencode = pkgs.runCommand "wrapper-smoke-opencode" { } ''
            ${pkgs.bash}/bin/bash -n ${
              library.mkWrappedTool {
                inherit pkgs;
                target = "opencode";
                tool = agentPkgs.opencode;
                agentSystem = opencodeConfig;
              }
            }/bin/opencode
            test -f ${opencodeConfig}/opencode.json
            test -d ${opencodeConfig}/agents
            touch $out
          '';

          wrapper-smoke-claude = pkgs.runCommand "wrapper-smoke-claude" { } ''
            ${pkgs.bash}/bin/bash -n ${
              library.mkWrappedTool {
                inherit pkgs;
                target = "claude";
                tool = agentPkgs.claude-code;
                agentSystem = claudeConfig;
              }
            }/bin/claude
            test -f ${claudeConfig}/settings.json
            test -f ${claudeConfig}/.mcp.json
            test -d ${claudeConfig}/agents
            touch $out
          '';

          schema-compat-codex =
            pkgs.runCommand "schema-compat-codex"
              {
                nativeBuildInputs = [ pkgs.check-jsonschema ];
              }
              ''
                check-jsonschema \
                  --schemafile ${./lib/schemas/codex-mcp.json} \
                  ${codexConfig}/mcp.json
                touch $out
              '';

          schema-compat-cursor =
            pkgs.runCommand "schema-compat-cursor"
              {
                nativeBuildInputs = [ pkgs.check-jsonschema ];
              }
              ''
                check-jsonschema \
                  --schemafile ${./lib/schemas/cursor-mcp.json} \
                  ${cursorConfig}/.cursor/mcp.json
                touch $out
              '';

          schema-compat-amp =
            pkgs.runCommand "schema-compat-amp"
              {
                nativeBuildInputs = [ pkgs.check-jsonschema ];
              }
              ''
                check-jsonschema \
                  --schemafile ${./lib/schemas/amp.json} \
                  ${ampConfig}/amp.json
                touch $out
              '';

          wrapper-smoke-codex = pkgs.runCommand "wrapper-smoke-codex" { } ''
            ${pkgs.bash}/bin/bash -n ${
              library.mkWrappedTool {
                inherit pkgs;
                target = "codex";
                tool = agentPkgs.codex;
                agentSystem = codexConfig;
              }
            }/bin/codex
            test -d ${codexConfig}/agents
            touch $out
          '';

          schema-compat-session =
            pkgs.runCommand "schema-compat-session"
              {
                nativeBuildInputs = [ pkgs.check-jsonschema ];
              }
              ''
                check-jsonschema --schemafile ${./lib/schemas/session.schema.json} \
                  ${./lib/schemas/fixtures/session-example.json}
                touch $out
              '';

          observe-service-build = pkgs.runCommand "observe-service-build" { } ''
            test -f ${self.packages.${system}.observe-service}/bin/agent-observe
            touch $out
          '';
        }
        // evals;
      }
    )
    // {
      overlays.default = final: prev: {
        pi-coding-agent = final.callPackage ./targets/pi/package { };
      };

      templates.default = {
        description = "Custom agent team using nix-agents";
        path = ./templates/default;
      };
    };
}
