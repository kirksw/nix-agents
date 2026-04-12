{ lib }:
let
  inherit (lib) mkOption types;

  permission = types.enum [
    "allow"
    "deny"
    "ask"
  ];

  permissionSet = types.submodule {
    options = {
      default = mkOption {
        type = permission;
        default = "allow";
        description = "Default permission for tool/path access.";
      };
      rules = mkOption {
        type = types.attrsOf permission;
        default = { };
        description = "Path or task permission overrides.";
      };
    };
  };

  permissionField = types.either permission permissionSet;

  overridesType = types.submodule {
    options = {
      opencode = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "OpenCode specific override fields.";
      };
      claudeCode = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Claude Code specific override fields.";
      };
      codex = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Codex specific override fields.";
      };
    };
  };

  orchestrationType = types.submodule {
    options = {
      patterns = mkOption {
        type = types.attrsOf types.lines;
        default = { };
        description = "Named delegation patterns, keyed by strategy title.";
      };
      antiPatterns = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Anti-patterns to avoid.";
      };
    };
  };

  permissionsType = types.submodule {
    options = {
      edit = mkOption {
        type = types.nullOr permissionField;
        default = null;
        description = "Edit permission. Null falls back to system defaultPermissions.";
      };
      bash = mkOption {
        type = types.nullOr permissionField;
        default = null;
        description = "Bash permission. Null falls back to system defaultPermissions.";
      };
      task = mkOption {
        type = types.nullOr permissionField;
        default = null;
        description = "Task permission. Null falls back to system defaultPermissions.";
      };
      webfetch = mkOption {
        type = types.nullOr permission;
        default = null;
        description = "Webfetch permission. Null falls back to system defaultPermissions.";
      };
    };
  };

  agentType = types.submodule {
    options = {
      description = mkOption {
        type = types.str;
        description = "One line description for tool UIs.";
      };
      model = mkOption {
        type = types.either (types.enum [
          "fast"
          "balanced"
          "powerful"
          "reasoning"
        ]) types.str;
        description = "Model capability tier or explicit model string.";
      };
      mode = mkOption {
        type = types.enum [
          "subagent"
          "primary"
        ];
        default = "subagent";
      };
      temperature = mkOption {
        type = types.number;
        default = 0.2;
      };
      reasoningEffort = mkOption {
        type = types.nullOr (
          types.enum [
            "low"
            "medium"
            "high"
            "xhigh"
          ]
        );
        default = null;
      };
      prompt = mkOption {
        type = types.lines;
        description = "Prompt body for the agent.";
      };
      tier = mkOption {
        type = types.nullOr (
          types.enum [
            "orchestrator"
            "manager"
            "employee"
          ]
        );
        default = null;
        description = "Tier in the delegation hierarchy. Null for flat-graph agents.";
      };
      managedAgents = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Agent names this manager/orchestrator can delegate to. Injected into prompt and used for future runtime filtering.";
      };
      extraTools = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional tools granted beyond tier defaults. Use sparingly for exceptions like COO needing read access.";
      };
      maxDelegationDepth = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Maximum recursive delegation depth. Null for system default.";
      };
      delegatesTo = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Agent delegation targets.";
      };
      permissions = mkOption {
        type = permissionsType;
        default = { };
      };
      skills = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      mcpServers = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      orchestration = mkOption {
        type = orchestrationType;
        default = { };
      };
      overrides = mkOption {
        type = overridesType;
        default = { };
      };
    };
  };

  skillType = types.submodule {
    options = {
      description = mkOption {
        type = types.str;
        description = "Skill description.";
      };
      content = mkOption {
        type = types.lines;
        default = "";
        description = "Markdown body for generated SKILL.md.";
      };
      resources = mkOption {
        type = types.attrsOf types.path;
        default = { };
      };
      src = mkOption {
        type = types.nullOr types.path;
        default = null;
      };
      version = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Semver string identifying this skill version. Used for efficacy tracking.";
      };
    };
  };

  mcpServerType = types.submodule {
    options = {
      enabled = mkOption {
        type = types.bool;
        default = true;
      };
      type = mkOption {
        type = types.enum [
          "local"
          "remote"
        ];
        default = "local";
      };
      command = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      package = mkOption {
        type = types.nullOr types.package;
        default = null;
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra arguments appended after the binary when command is resolved from package. Ignored when command is set explicitly.";
      };
      url = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      transport = mkOption {
        type = types.nullOr (
          types.enum [
            "sse"
            "http"
          ]
        );
        default = null;
      };
      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
    };
  };

  eventType = types.enum [
    "session-start"
    "session-end"
    "delegation"
    "skill-invoked"
    "human-decision"
    "commit"
    "error"
  ];

  hookType = types.submodule {
    options = {
      event = mkOption {
        type = eventType;
        description = "Event that triggers this hook.";
      };
      command = mkOption {
        type = types.str;
        description = "Shell command to run. Receives event JSON on stdin.";
      };
      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Nix package to add to PATH when running this hook.";
      };
    };
  };

  cognitiveStyleType = types.enum [
    "adhd"
    "dyslexia"
    "detail-focused"
    "high-level"
    "visual"
  ];

  gitIdentityType = types.submodule {
    options = {
      userName = mkOption {
        type = types.str;
        description = "Git user.name for commits in this base.";
      };
      userEmail = mkOption {
        type = types.str;
        description = "Git user.email for commits in this base.";
      };
      signingKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path or ID of the git signing key. Null disables signing env hint.";
      };
      gpgFormat = mkOption {
        type = types.enum [ "openpgp" "ssh" "x509" ];
        default = "ssh";
        description = "Git gpg.format value.";
      };
    };
  };

  humanType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        default = "";
        description = "Human operator name.";
      };
      cognitiveStyle = mkOption {
        type = types.nullOr cognitiveStyleType;
        default = null;
        description = "Cognitive style hint; expands to communication rules injected into all agent prompts.";
      };
      context = mkOption {
        type = types.lines;
        default = "";
        description = "Free-form preferences injected verbatim into the preamble.";
      };
      rules = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Hard rules injected as a numbered list in the preamble.";
      };
    };
  };

  providerType = types.submodule {
    options = {
      credentialSource = mkOption {
        type = types.enum [
          "env"
          "protonpass"
          "apple-keychain"
          "sops"
        ];
        description = "Where the credential lives.";
      };
      credentialRef = mkOption {
        type = types.str;
        description = "Key name, env var name, or sops path.";
      };
      envVar = mkOption {
        type = types.str;
        description = "Env var the tool expects at runtime.";
      };
    };
  };

  baseType = types.submodule {
    options = {
      stateDir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override for base runtime state directory. Null uses the target default.";
      };
      providers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Provider names scoped to this base. Profiles within this base inherit these providers.";
      };
      human = mkOption {
        type = types.nullOr humanType;
        default = null;
        description = "Base-scoped operator context. Profiles inherit this unless they override.";
      };
      git = mkOption {
        type = types.nullOr gitIdentityType;
        default = null;
        description = "Git identity for commits in this base. Exported as GIT_AUTHOR/COMMITTER env vars by wrappers.";
      };
      defaultProfile = mkOption {
        type = types.str;
        default = "default";
        description = "Name of the default profile within this base.";
      };
      pathPrefixes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Filesystem path prefixes that activate profiles in this base.";
      };
    };
  };

  profileType = types.submodule {
    options = {
      base = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Base this profile belongs to. When null, the profile uses the implicit
          "default" base during migration. In the future, this will become required.
        '';
      };
      pathPrefixes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Filesystem path prefixes this profile activates for.";
      };
      providers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Provider names (keys in config.providers) active in this profile.";
      };
      agents = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Agent names included. Empty means all.";
      };
      skills = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Skill names included. Empty means all.";
      };
      mcpServers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "MCP server names included. Empty means all.";
      };
      human = mkOption {
        type = types.nullOr humanType;
        default = null;
        description = "Human context override for this profile.";
      };
      tierMapping = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Profile-local tier overrides merged over system tierMapping.";
      };
      permissions = mkOption {
        type = types.nullOr permissionsType;
        default = null;
        description = "Profile-local permission defaults.";
      };
    };
  };
in
{
  inherit
    permission
    permissionSet
    permissionField
    permissionsType
    orchestrationType
    overridesType
    agentType
    skillType
    mcpServerType
    eventType
    hookType
    gitIdentityType
    cognitiveStyleType
    humanType
    providerType
    baseType
    profileType
    ;
  agents = types.attrsOf agentType;
  skills = types.attrsOf skillType;
  mcpServers = types.attrsOf mcpServerType;
  hooks = types.listOf hookType;
  providers = types.attrsOf providerType;
  bases = types.attrsOf baseType;
  profiles = types.attrsOf profileType;
}
