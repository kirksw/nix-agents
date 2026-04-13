# ADR-0001 base/profile preset.
# Each base represents an environment boundary (work/personal) that owns
# shared runtime state (credentials, auth, sessions). Profiles are
# configuration overlays within a base.

_: {
  providers = {
    personal-zai-key = {
      credentialSource = "file";
      credentialRef = "/Users/kisw/.config/sops-nix/secrets/zai";
      envVar = "ZAI_API_KEY";
    };
    personal-minimax-key = {
      credentialSource = "file";
      credentialRef = "/Users/kisw/.config/sops-nix/secrets/minimax";
      envVar = "MINIMAX_API_KEY";
    };
  };

  bases = {
    # personal — personal projects, full agent access, own credentials
    personal = {
      pathPrefixes = [
        "~/src/"
        "~/projects/"
      ];
      providers = [
        "personal-zai-key"
        "personal-minimax-key"
      ];
      defaultProfile = "stable";
      git = {
        userName = "Kirk Sweeney";
        userEmail = "kirk@cntd.io";
        signingKey = "/Users/kisw/.config/sops-nix/secrets/ssh/kirksw/private";
        gpgFormat = "ssh";
      };
    };

    # work — work projects, restricted agent set, shared work credentials
    work = {
      pathPrefixes = [
        "~/git/github.com/lunarway/"
        "~/projects/lunar/"
      ];
      providers = [ ];
      defaultProfile = "default";
      git = {
        userName = "Kirk Sweeney";
        userEmail = "kisw@lunar.app";
        signingKey = "/Users/kisw/.config/sops-nix/secrets/ssh/lunarway/private";
        gpgFormat = "ssh";
      };
    };
  };

  profiles = {
    # --- personal profiles ---

    personal-default = {
      base = "personal";
      pathPrefixes = [ ];
      agents = [ ]; # empty = all
      skills = [ ]; # empty = all
      mcpServers = [ ]; # empty = all
      tierMapping = { };
    };

    # --- work profiles ---

    # work/stable: conservative model tiers, stricter permissions
    work-default = {
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
      skills = [
        "nix-agents"
        "system-context"
      ];
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
  };
}
