# ADR-0001 base/profile preset.
# Each base represents an environment boundary (work/personal) that owns
# shared runtime state (credentials, auth, sessions). Profiles are
# configuration overlays within a base.

_: {
  bases = {
    # personal — personal projects, full agent access, own credentials
    personal = {
      pathPrefixes = [
        "~/src/"
        "~/projects/"
      ];
      providers = [ ];
      defaultProfile = "stable";
    };

    # work — work projects, restricted agent set, shared work credentials
    work = {
      pathPrefixes = [ "~/work/" ];
      providers = [ ];
      defaultProfile = "stable";
    };
  };

  profiles = {
    # --- personal profiles ---

    personal-stable = {
      base = "personal";
      pathPrefixes = [ ];
      agents = [ ]; # empty = all
      skills = [ ]; # empty = all
      mcpServers = [ ]; # empty = all
      tierMapping = { };
    };

    # --- work profiles ---

    # work/stable: conservative model tiers, stricter permissions
    work-stable = {
      base = "work";
      pathPrefixes = [ ];
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
        reasoning = "anthropic/claude-opus-4-6";
      };
      permissions = {
        edit = null;
        bash = null;
        task = null;
        webfetch = "deny";
      };
    };

    # work/team: same work auth, team-optimized delegation
    # (future: add team-specific agents/skills here)
    work-team = {
      base = "work";
      pathPrefixes = [ ];
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
        reasoning = "anthropic/claude-opus-4-6";
      };
      permissions = {
        edit = null;
        bash = null;
        task = null;
        webfetch = "deny";
      };
    };
  };
}
