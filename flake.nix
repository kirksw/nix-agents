{
  description = "Composable LLM agent configuration generators";

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

        exampleModules = [
          ./templates/default/agents/my-agent.nix
          {
            human = {
              name = "Example Operator";
              context = "Use these generated configs as a starting point for your own agent team.";
            };

            skills.project-context = {
              description = "Project-specific context loaded from the generated example.";
              content = ''
                # Project Context

                Replace this skill with your own project conventions, workflows, and constraints.
              '';
              version = "0.1.0";
            };

            mcpServers.example-api = {
              type = "remote";
              transport = "http";
              url = "https://example.invalid/mcp";
            };

            providers.example-key = {
              credentialSource = "env";
              credentialRef = "EXAMPLE_API_KEY";
              envVar = "EXAMPLE_API_KEY";
            };

            sandboxes.default = {
              uploadProject = true;
              uploadProfileConfig = true;
            };

            bases.default = {
              pathPrefixes = [ "~/src/" ];
              providers = [ "example-key" ];
            };

            tierMapping.S = [
              "anthropic/claude-sonnet-4-5"
              "anthropic/claude-haiku-4-5-20251001"
            ];

            profiles.default = {
              base = "default";
              agents = [ "my-agent" ];
              skills = [ "project-context" ];
              mcpServers = [ "example-api" ];
              sandbox = "default";
            };
          }
        ];

        mkTargetConfig =
          target:
          library.mkAgentSystem {
            inherit pkgs target;
            modules = exampleModules;
            src = if target == "opencode" then ./templates/default else null;
          };

        opencodeConfig = mkTargetConfig "opencode";
        claudeConfig = mkTargetConfig "claude";
        codexConfig = mkTargetConfig "codex";
        piConfig = mkTargetConfig "pi";
        cursorConfig = mkTargetConfig "cursor";
        ampConfig = mkTargetConfig "amp";

        mkProfileMeta =
          target:
          library.mkProfileMeta {
            inherit pkgs target;
            modules = exampleModules;
            src = if target == "opencode" then ./templates/default else null;
          };

        opencodeProfileMeta = mkProfileMeta "opencode";
        claudeProfileMeta = mkProfileMeta "claude";
        codexProfileMeta = mkProfileMeta "codex";
        piProfileMeta = mkProfileMeta "pi";

        opencodeWrapper = library.mkWrappedTool {
          inherit pkgs;
          target = "opencode";
          tool = agentPkgs.opencode;
          agentSystem = opencodeConfig;
          profileMeta = opencodeProfileMeta;
        };

        claudeWrapper = library.mkWrappedTool {
          inherit pkgs;
          target = "claude";
          tool = agentPkgs.claude-code;
          agentSystem = claudeConfig;
          profileMeta = claudeProfileMeta;
        };

        codexWrapper = library.mkWrappedTool {
          inherit pkgs;
          target = "codex";
          tool = agentPkgs.codex;
          agentSystem = codexConfig;
          profileMeta = codexProfileMeta;
        };

        piWrapper = library.mkWrappedTool {
          inherit pkgs;
          target = "pi";
          tool = agentPkgs.pi;
          agentSystem = piConfig;
          profileMeta = piProfileMeta;
        };

        evaluatedConfig = library.evalModules { modules = exampleModules; };
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
            piConfig
            opencodeWrapper
            claudeWrapper
            codexWrapper
            piWrapper
            ;
        };

        evalCheckNames = builtins.attrNames evals;

        benchScript = pkgs.writeShellScriptBin "bench" ''
          set -euo pipefail
          echo "Running eval suite..."
          nix build ${pkgs.lib.concatStringsSep " " (map (name: ".#checks.${system}.${name}") evalCheckNames)}
          echo "All evals passed."
        '';

        nixFiles = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = pkgs.lib.fileset.fileFilter (f: f.hasExt "nix") ./.;
        };
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
          inherit (pkgs) openshell;
          opencode-config = opencodeConfig;
          claude-config = claudeConfig;
          codex-config = codexConfig;
          pi-config = piConfig;
          cursor-config = cursorConfig;
          amp-config = ampConfig;

          opencode = opencodeWrapper;

          claude = claudeWrapper;

          codex = codexWrapper;

          pi = piWrapper;

          default = opencodeConfig;
        };

        apps = {
          graph = {
            type = "app";
            program = "${graphScript}/bin/graph";
          };

          bench = {
            type = "app";
            program = "${benchScript}/bin/bench";
          };

          openshell = {
            type = "app";
            program = "${self.packages.${system}.openshell}/bin/openshell";
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
          config-gen-opencode = opencodeConfig;
          config-gen-claude = claudeConfig;
          config-gen-codex = codexConfig;
          config-gen-pi = piConfig;
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

          schema-compat-claude =
            pkgs.runCommand "schema-compat-claude" { nativeBuildInputs = [ pkgs.check-jsonschema ]; }
              ''
                check-jsonschema --schemafile ${./lib/schemas/claude-code-settings.json} ${claudeConfig}/settings.json
                check-jsonschema --schemafile ${./lib/schemas/claude-code-mcp.json} ${claudeConfig}/.mcp.json
                touch $out
              '';

          schema-compat-opencode =
            pkgs.runCommand "schema-compat-opencode" { nativeBuildInputs = [ pkgs.check-jsonschema ]; }
              ''
                check-jsonschema --schemafile ${./lib/schemas/opencode-config.json} ${opencodeConfig}/opencode.json
                touch $out
              '';

          schema-compat-codex =
            pkgs.runCommand "schema-compat-codex" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                python -c 'import pathlib, tomllib; data = tomllib.loads(pathlib.Path("${codexConfig}/mcp.nix.toml").read_text()); assert isinstance(data.get("mcp_servers", {}), dict)'
                touch $out
              '';

          schema-compat-cursor =
            pkgs.runCommand "schema-compat-cursor" { nativeBuildInputs = [ pkgs.check-jsonschema ]; }
              ''
                check-jsonschema --schemafile ${./lib/schemas/cursor-mcp.json} ${cursorConfig}/.cursor/mcp.json
                touch $out
              '';

          schema-compat-amp =
            pkgs.runCommand "schema-compat-amp" { nativeBuildInputs = [ pkgs.check-jsonschema ]; }
              ''
                check-jsonschema --schemafile ${./lib/schemas/amp.json} ${ampConfig}/amp.json
                touch $out
              '';

          wrapper-smoke-profile-paths = pkgs.runCommand "wrapper-smoke-profile-paths" { } ''
            for wrapper in \
              ${self.packages.${system}.opencode}/bin/opencode \
              ${self.packages.${system}.claude}/bin/claude \
              ${self.packages.${system}.codex}/bin/codex \
              ${self.packages.${system}.pi}/bin/pi
            do
              ${pkgs.bash}/bin/bash -n "$wrapper"
              grep -q 'bases/\$NAX_BASE/profiles/\$NAX_PROFILE' "$wrapper"
              grep -q 'export NAX_BASE=' "$wrapper"
            done
            grep -q 'openshell.*/bin/openshell' ${self.packages.${system}.codex}/bin/codex
            grep -q 'sandbox create' ${self.packages.${system}.codex}/bin/codex
            touch $out
          '';
        }
        // evals;
      }
    )
    // {
      overlays.default = final: _prev: {
        pi-coding-agent = llm-agents.packages.${final.system}.pi;
      };

      templates.default = {
        description = "Custom agent team using nix-agents";
        path = ./templates/default;
      };
    };
}
