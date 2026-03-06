{ lib, types, ... }:
{
  options.mcpServers = lib.mkOption {
    type = types.mcpServers;
    default = { };
    description = "Configured MCP servers available to agents.";
  };
}
