{ ... }:
{
  imports = [
    ../agents/code-monkey.nix
    ../agents/explore.nix
    ../skills/swe-pruner-mcp.nix
    ../mcp-servers/swe-pruner.nix
  ];
}
