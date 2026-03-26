{ ... }:
{
  profiles = {
    # personal — activated for ~/src/ and ~/projects/ paths.
    # All agents and skills available; use reasoning model for architecture tasks.
    personal = {
      pathPrefixes = [
        "~/src/"
        "~/projects/"
      ];
      agents = [ ]; # empty = all
      skills = [ ]; # empty = all
      mcpServers = [ ]; # empty = all
      tierMapping = { };
    };

    # work — activated for ~/work/ paths.
    # Restricted agent set and no external web fetching.
    # Downgrades expensive models to sonnet to control costs.
    work = {
      pathPrefixes = [ "~/work/" ];
      agents = [
        "code-monkey"
        "explore"
        "bottleneck"
        "scribe"
      ];
      skills = [
        "swe-pruner-mcp"
        "nix-module-workflow"
      ];
      mcpServers = [ "swe-pruner" ];
      tierMapping = {
        powerful = "anthropic/claude-sonnet-4-6";
        reasoning = "anthropic/claude-sonnet-4-6";
      };
      permissions = {
        edit = null;
        bash = null;
        task = null;
        webfetch = "deny";
      };
    };

    # nix-ops — activated for ~/src/nixfiles/ and ~/.config/ paths.
    # Full agent set with Nix-specific skill whitelist.
    # Uses opus for reasoning tasks (heavy architecture work).
    nix-ops = {
      pathPrefixes = [
        "~/src/nixfiles/"
        "~/.config/"
      ];
      agents = [ ]; # all agents
      skills = [
        "swe-pruner-mcp"
        "nix-coding-style"
        "nix-flake-ops"
        "nix-module-workflow"
        "secrets-management"
      ];
      mcpServers = [ "swe-pruner" ];
      tierMapping = {
        reasoning = "anthropic/claude-opus-4-6";
      };
    };
  };
}
