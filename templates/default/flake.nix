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

        myAgentSystem = agentsLib.mkAgentSystem {
          inherit pkgs;
          modules = [
            ../../presets/default.nix
            ./agents/my-agent.nix
            {
              agents.code-monkey.model = "anthropic/claude-sonnet-4-5";
              mcpServers.my-server = {
                type = "remote";
                url = "https://my-api.example.com/mcp";
              };
            }
          ];
          target = "opencode";
        };
      in
      {
        packages = {
          opencode-config = myAgentSystem;
          opencode = agentsLib.mkWrappedTool {
            inherit pkgs;
            target = "opencode";
            tool = agentPkgs.opencode;
            agentSystem = myAgentSystem;
          };
        };

        devShells.default = pkgs.mkShell {
          name = "my-agent-team";
          packages = with pkgs; [
            nixfmt-rfc-style
            statix
          ];
        };
      }
    );
}
