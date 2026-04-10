{ pkgs, ... }:
{
  mcpServers.agent-observe = {
    type = "local";
    package = pkgs.callPackage ../../services/agent-observe { };
    args = [ "mcp" ];
  };
}
