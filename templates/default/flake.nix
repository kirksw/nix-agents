{
  description = "Custom agent team using nix-agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-agents.url = "github:kirksw/nix-agents";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      nix-agents,
      llm-agents,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        agentPkgs = llm-agents.packages.${system};
        agentsLib = nix-agents.lib.${system};

        modules = [
          ./agents/my-agent.nix
          {
            skills.project-context = {
              description = "Project-specific context.";
              content = ''
                # Project Context

                Add your project conventions here.
              '';
            };

            mcpServers.example-api = {
              type = "remote";
              transport = "http";
              url = "https://example.invalid/mcp";
            };

            bases.default.pathPrefixes = [ "~/src/" ];
            profiles.default = {
              base = "default";
              agents = [ "my-agent" ];
              skills = [ "project-context" ];
              mcpServers = [ "example-api" ];
            };
          }
        ];

        opencodeConfig = agentsLib.mkAgentSystem {
          inherit pkgs modules;
          target = "opencode";
          src = ./.;
        };

        profileMeta = agentsLib.mkProfileMeta {
          inherit pkgs modules;
          target = "opencode";
          src = ./.;
        };
      in
      {
        packages = {
          opencode-config = opencodeConfig;
          opencode = agentsLib.mkWrappedTool {
            inherit pkgs profileMeta;
            target = "opencode";
            tool = agentPkgs.opencode;
            agentSystem = opencodeConfig;
          };
        };

        checks.config-gen-opencode = opencodeConfig;
      }
    );
}
