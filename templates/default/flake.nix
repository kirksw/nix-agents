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

        # Available presets:
        #   ${nix-agents}/presets/default.nix   - full team (all agents, skills, MCP servers)
        #   ${nix-agents}/presets/minimal.nix   - code-monkey + explore only
        #   ${nix-agents}/presets/security.nix  - minimal + bottleneck + code-red
        preset = "${nix-agents}/presets/default.nix";

        myAgentSystem = agentsLib.mkAgentSystem {
          inherit pkgs;
          target = "opencode";
          modules = [
            preset

            # Add your own agent definitions
            ./agents/my-agent.nix

            # Inline overrides
            {
              # Override model tier mappings globally
              # tierMapping.reasoning = "anthropic/claude-opus-4-6";
              # tierMapping.balanced = "anthropic/claude-sonnet-4-5";

              # Override system-wide permission defaults
              # defaultPermissions = {
              #   edit = "allow";
              #   bash = "ask";
              # };

              # Override a specific agent's model
              # agents.code-monkey.model = "anthropic/claude-sonnet-4-5";

              # Add an MCP server
              mcpServers.my-server = {
                type = "remote";
                transport = "http";
                url = "https://my-api.example.com/mcp";
              };
            }
          ];
        };

        claudeSystem = agentsLib.mkAgentSystem {
          inherit pkgs;
          target = "claude";
          modules = [
            preset
            ./agents/my-agent.nix
          ];
        };
      in
      {
        packages = {
          opencode-config = myAgentSystem;
          claude-config = claudeSystem;

          opencode = agentsLib.mkWrappedTool {
            inherit pkgs;
            target = "opencode";
            tool = agentPkgs.opencode;
            agentSystem = myAgentSystem;
          };

          claude = agentsLib.mkWrappedTool {
            inherit pkgs;
            target = "claude";
            tool = agentPkgs.claude-code;
            agentSystem = claudeSystem;
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
