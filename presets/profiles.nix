_: {
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
        "10xBEAST"
        "the-architect"
        "code-monkey"
        "explore"
        "bottleneck"
        "chaos-demon"
        "code-red"
        "scribe"
      ];
      skills = [ "nix-module-workflow" ];
      mcpServers = [ ];
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
        "nix-coding-style"
        "nix-flake-ops"
        "nix-module-workflow"
        "secrets-management"
      ];
      mcpServers = [ ];
      tierMapping = {
        reasoning = "anthropic/claude-opus-4-6";
      };
    };
  };
}
