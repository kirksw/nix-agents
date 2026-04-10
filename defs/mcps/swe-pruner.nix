{ pkgs, ... }:
{
  mcpServers.swe-pruner = {
    type = "local";
    command = [ "${pkgs.callPackage ../../services/swe-pruner { }}/bin/swe-pruner-mcp" ];
  };
}
