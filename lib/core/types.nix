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
      url = mkOption {
        type = types.nullOr types.str;
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
    ;
  agents = types.attrsOf agentType;
  skills = types.attrsOf skillType;
  mcpServers = types.attrsOf mcpServerType;
}
