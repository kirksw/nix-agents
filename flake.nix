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
        defaultModules = [
          ./presets/default.nix
          ./presets/profiles.nix
        ];

        tieredModules = [
          ./presets/tiered.nix
          ./presets/profiles.nix
        ];

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

        mkTieredConfigWithSrc =
          target:
          library.mkAgentSystem {
            inherit pkgs target;
            modules = tieredModules;
            src = ./.;
          };

        tieredPiConfig = mkTieredConfigWithSrc "pi";
        cursorConfig = mkConfig "cursor";
        ampConfig = mkConfig "amp";
        opencodeProfileMeta = library.mkProfileMeta {
          inherit pkgs;
          modules = defaultModules;
          target = "opencode";
          src = ./.;
        };
        claudeProfileMeta = library.mkProfileMeta {
          inherit pkgs;
          modules = defaultModules;
          target = "claude";
        };
        codexProfileMeta = library.mkProfileMeta {
          inherit pkgs;
          modules = defaultModules;
          target = "codex";
        };
        piProfileMeta = library.mkProfileMeta {
          inherit pkgs;
          modules = tieredModules;
          target = "pi";
          src = ./.;
        };

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
            tieredPiConfig
            ;
        };

        evalCheckNames = builtins.attrNames evals;

        benchScript = pkgs.writeShellScriptBin "bench" ''
          set -euo pipefail
          echo "Running eval suite..."
          nix build ${pkgs.lib.concatStringsSep " " (map (name: ".#checks.${system}.${name}") evalCheckNames)}
          echo "All evals passed."
        '';

        mkProfileSyncBlock =
          {
            label,
            targetName,
            defaultConfig,
            profileMeta,
            files,
            optionalTrees ? [ ],
          }:
          let
            # Sync one profile's store path to the base/profile directory layout.
            renderOne = base: profileName: storePath: ''
              if [ -d "${storePath}" ]; then
                echo "Syncing ${label} to $NIX_AGENTS_DIR/${targetName}/bases/${base}/profiles/${profileName}..."
                sync_tree "${storePath}/agents" "$NIX_AGENTS_DIR/${targetName}/bases/${base}/profiles/${profileName}/agents"
                sync_tree "${storePath}/skills" "$NIX_AGENTS_DIR/${targetName}/bases/${base}/profiles/${profileName}/skills"
                ${pkgs.lib.concatMapStringsSep "\n" (
                  file:
                  ''sync_file "${storePath}/${file.source}" "$NIX_AGENTS_DIR/${targetName}/bases/${base}/profiles/${profileName}/${file.target}"''
                ) files}
                ${pkgs.lib.concatMapStringsSep "\n" (
                  tree:
                  ''sync_optional_tree "${storePath}/${tree.source}" "$NIX_AGENTS_DIR/${targetName}/bases/${base}/profiles/${profileName}/${tree.target}"''
                ) optionalTrees}
              fi
            '';
          in
          # Default config goes to default/default (implicit base)
          renderOne "default" "default" defaultConfig
          + "\n"
          + pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (
              profileName: meta: renderOne meta.base profileName meta.storePath
            ) profileMeta
          );

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

          sync_optional_tree() {
            source_dir="$1"
            target_dir="$2"

            if [ -d "$source_dir" ]; then
              sync_tree "$source_dir" "$target_dir"
            else
              ${pkgs.coreutils}/bin/rm -rf "$target_dir"
            fi
          }

          sync_file() {
            source_file="$1"
            target_file="$2"

            ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target_file")"
            if [ -f "$source_file" ]; then
              ${pkgs.coreutils}/bin/chmod u+w "$target_file" 2>/dev/null || true
              ${pkgs.coreutils}/bin/rm -f "$target_file"
              ${pkgs.coreutils}/bin/cp "$source_file" "$target_file"
              ${pkgs.coreutils}/bin/chmod u+w "$target_file" 2>/dev/null || true
            else
              ${pkgs.coreutils}/bin/chmod u+w "$target_file" 2>/dev/null || true
              ${pkgs.coreutils}/bin/rm -f "$target_file"
            fi
          }

          CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}"
          DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}"
          NIX_AGENTS_DIR="$CONFIG_DIR/nix-agents"

          # OpenCode
          ${mkProfileSyncBlock {
            label = "OpenCode";
            targetName = "opencode";
            defaultConfig = opencodeConfig;
            profileMeta = opencodeProfileMeta;
            files = [
              {
                source = "AGENTS.md";
                target = "AGENTS.md";
              }
              {
                source = "opencode.json";
                target = "opencode.json";
              }
            ];
          }}

          # Claude
          ${mkProfileSyncBlock {
            label = "Claude";
            targetName = "claude";
            defaultConfig = claudeConfig;
            profileMeta = claudeProfileMeta;
            files = [
              {
                source = "CLAUDE.md";
                target = "CLAUDE.md";
              }
              {
                source = "settings.json";
                target = "settings.json";
              }
              {
                source = ".mcp.json";
                target = ".mcp.json";
              }
            ];
          }}

          # Codex
          ${mkProfileSyncBlock {
            label = "Codex";
            targetName = "codex";
            defaultConfig = codexConfig;
            profileMeta = codexProfileMeta;
            files = [
              {
                source = "AGENTS.md";
                target = "AGENTS.md";
              }
              {
                source = "mcp.json";
                target = "mcp.json";
              }
            ];
          }}

          # Pi (tiered config — includes all flat agents + orchestrator/managers)
          ${mkProfileSyncBlock {
            label = "Pi";
            targetName = "pi";
            defaultConfig = tieredPiConfig;
            profileMeta = piProfileMeta;
            files = [
              {
                source = "AGENTS.md";
                target = "AGENTS.md";
              }
            ];
            optionalTrees = [
              {
                source = "extensions";
                target = "extensions";
              }
              {
                source = "prompts";
                target = "prompts";
              }
            ];
          }}

          # Cursor
          if [ -d "${cursorConfig}" ]; then
            echo "Syncing Cursor to $HOME/.cursor..."
            ${pkgs.coreutils}/bin/mkdir -p "$HOME/.cursor/rules"
            sync_optional_tree "${cursorConfig}/.cursor/rules" "$HOME/.cursor/rules"
            ${pkgs.coreutils}/bin/cp "${cursorConfig}/.cursor/mcp.json" "$HOME/.cursor/mcp.json" 2>/dev/null || true
          fi

          # Amp
          if [ -d "${ampConfig}" ]; then
            echo "Syncing Amp to $CONFIG_DIR/amp..."
            sync_optional_tree "${ampConfig}/agents" "$CONFIG_DIR/amp/agents"
            sync_optional_tree "${ampConfig}/skills" "$CONFIG_DIR/amp/skills"
            ${pkgs.coreutils}/bin/cp "${ampConfig}/AGENTS.md" "$CONFIG_DIR/amp/AGENTS.md" 2>/dev/null || true
            ${pkgs.coreutils}/bin/cp "${ampConfig}/amp.json" "$CONFIG_DIR/amp/amp.json" 2>/dev/null || true
          fi

          echo "Done!"
        '';
      in
      {
        lib = {
          inherit (library) evalModules types;
          inherit (library)
            mkAgentSystem
            mkProfileMeta
            mkWrappedTool
            resolveBaseProfile
            ;
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
            profileMeta = opencodeProfileMeta;
          };
          claude = library.mkWrappedTool {
            inherit pkgs;
            target = "claude";
            tool = agentPkgs.claude-code;
            agentSystem = claudeConfig;
            profileMeta = claudeProfileMeta;
          };
          codex = library.mkWrappedTool {
            inherit pkgs;
            target = "codex";
            tool = agentPkgs.codex;
            agentSystem = codexConfig;
            profileMeta = codexProfileMeta;
          };
          pi = library.mkWrappedTool {
            inherit pkgs;
            target = "pi";
            tool = piCodingAgent;
            agentSystem = tieredPiConfig;
            profileMeta = piProfileMeta;
          };
          cursor-config = cursorConfig;
          amp-config = ampConfig;
          tiered-pi-config = tieredPiConfig;
          pi-coding-agent = piCodingAgent;
          update-script = updateScript;
          observe-service = pkgs.callPackage ./services/agent-observe { };
          swe-pruner = pkgs.callPackage ./services/swe-pruner { };
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
                check-jsonschema \
                  --schemafile ${./lib/schemas/claude-code-mcp.json} \
                  ${claudeConfig}/.mcp.json
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

          wrapper-smoke-profile-paths = pkgs.runCommand "wrapper-smoke-profile-paths" { } ''
            opencode_wrapper=${
              library.mkWrappedTool {
                inherit pkgs;
                target = "opencode";
                tool = agentPkgs.opencode;
                agentSystem = opencodeConfig;
                profile = "work";
              }
            }/bin/opencode
            claude_wrapper=${
              library.mkWrappedTool {
                inherit pkgs;
                target = "claude";
                tool = agentPkgs.claude-code;
                agentSystem = claudeConfig;
                profile = "work";
              }
            }/bin/claude
            codex_wrapper=${
              library.mkWrappedTool {
                inherit pkgs;
                target = "codex";
                tool = agentPkgs.codex;
                agentSystem = codexConfig;
                profile = "work";
              }
            }/bin/codex
            pi_wrapper=${
              library.mkWrappedTool {
                inherit pkgs;
                target = "pi";
                tool = piCodingAgent;
                agentSystem = piConfig;
                profile = "work";
              }
            }/bin/pi

            # All wrappers must use the base/profile directory layout
            grep -q 'bases/\$NAX_BASE/profiles/\$NAX_PROFILE' "$opencode_wrapper"
            grep -q 'bases/\$NAX_BASE/profiles/\$NAX_PROFILE' "$claude_wrapper"
            grep -q 'bases/\$NAX_BASE/profiles/\$NAX_PROFILE' "$codex_wrapper"
            grep -q 'bases/\$NAX_BASE/profiles/\$NAX_PROFILE' "$pi_wrapper"

            # Pi must use base-scoped shared state
            grep -q '\$HOME/.pi/agent/bases/\$NAX_BASE' "$pi_wrapper"

            # All wrappers must export NAX_BASE
            grep -q 'export NAX_BASE=' "$opencode_wrapper"
            grep -q 'export NAX_BASE=' "$claude_wrapper"
            grep -q 'export NAX_BASE=' "$codex_wrapper"
            grep -q 'export NAX_BASE=' "$pi_wrapper"
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
