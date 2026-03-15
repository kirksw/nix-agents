_:
{
  mcpServers.agent-observe = {
    type = "local";
    # package is set at flake level where pkgs is available
    command = [
      "agent-observe"
      "mcp"
    ];
  };
}
