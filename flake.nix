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

        nixFiles = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = pkgs.lib.fileset.fileFilter (f: f.hasExt "nix") ./.;
        };
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
      templates.default = {
        description = "Custom agent team using nix-agents";
        path = ./templates/default;
      };
    };
}
