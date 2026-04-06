{ lib, evalModules }:
let
  opencodeGenerator = import ../generators/opencode.nix;
  claudeCodeGenerator = import ../generators/claude-code.nix;
  codexGenerator = import ../generators/codex.nix;
  piGenerator = import ../generators/pi.nix;
  cursorGenerator = import ../generators/cursor.nix;
  ampGenerator = import ../generators/amp.nix;

  mkGenerator =
    target:
    if target == "claude" then
      claudeCodeGenerator
    else if target == "codex" then
      codexGenerator
    else if target == "pi" then
      piGenerator
    else if target == "cursor" then
      cursorGenerator
    else if target == "amp" then
      ampGenerator
    else
      opencodeGenerator;

  # Resolve a named profile against the full config, returning a filtered/overridden config.
  resolveProfile =
    config: profileName:
    let
      profile = config.profiles.${profileName};

      filterByWhitelist =
        whitelist: attrset:
        if whitelist == [ ] then
          attrset
        else
          lib.filterAttrs (name: _: builtins.elem name whitelist) attrset;

      resolvedHuman = if profile.human != null then profile.human else config.human;

      resolvedTierMapping = config.tierMapping // profile.tierMapping;

      resolvedDefaultPermissions =
        if profile.permissions != null then
          # Merge profile permissions over system defaults
          {
            edit =
              if profile.permissions.edit != null then
                profile.permissions.edit
              else
                config.defaultPermissions.edit;
            bash =
              if profile.permissions.bash != null then
                profile.permissions.bash
              else
                config.defaultPermissions.bash;
            task =
              if profile.permissions.task != null then
                profile.permissions.task
              else
                config.defaultPermissions.task;
            webfetch =
              if profile.permissions.webfetch != null then
                profile.permissions.webfetch
              else
                config.defaultPermissions.webfetch;
          }
        else
          config.defaultPermissions;
    in
    config
    // {
      agents = filterByWhitelist profile.agents config.agents;
      skills = filterByWhitelist profile.skills config.skills;
      mcpServers = filterByWhitelist profile.mcpServers config.mcpServers;
      human = resolvedHuman;
      tierMapping = resolvedTierMapping;
      defaultPermissions = resolvedDefaultPermissions;
    };

  mkAgentSystem =
    {
      pkgs,
      modules ? [ ],
      target ? "opencode",
      src ? null,
      inputs ? { },
      profile ? null,
    }:
    let
      evaluated = evalModules {
        inherit modules;
        specialArgs = { inherit inputs; };
      };
      rawConfig = evaluated.config;
      config = if profile != null then resolveProfile rawConfig profile else rawConfig;
      generated = mkGenerator target {
        inherit
          lib
          config
          pkgs
          src
          ;
      };

      # Each hook command is compiled to a store-path shell script to avoid
      # multiline command embedding in the manifest and to eliminate eval on
      # arbitrary strings in the wrapper.
      hookScripts = lib.imap0 (
        i: hook:
        let
          script = pkgs.writeShellScript "nix-agents-hook-${hook.event}-${toString i}" (
            (lib.optionalString (hook.package != null) ''
              export PATH="${hook.package}/bin:$PATH"
            '')
            + hook.command
          );
        in
        {
          inherit (hook) event;
          path = "${script}";
        }
      ) config.hooks;

      hookManifest = builtins.toFile "hook-manifest" (
        lib.concatMapStringsSep "\n" (h: "${h.event}:${h.path}") hookScripts
      );

      skillVersions = lib.mapAttrs (
        _: skill: if skill.version != null then skill.version else "unversioned"
      ) config.skills;

      skillVersionManifest = pkgs.writeText "skill-versions.json" (builtins.toJSON skillVersions);

      writeAgent = name: content: ''
        cp ${builtins.toFile "agent-${name}.md" content} "$out/agents/${name}.md"
      '';

      skillContent =
        name: skill:
        if skill.src != null then
          builtins.unsafeDiscardStringContext (builtins.readFile (skill.src + "/SKILL.md"))
        else
          skill.content;

      writeSkill = name: content: ''
        mkdir -p "$out/skills/${name}"
        cp ${builtins.toFile "skill-${name}.md" content} "$out/skills/${name}/SKILL.md"
      '';

      commonOutputs = ''
        mkdir -p "$out/agents" "$out/skills"
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList writeAgent generated.agents)}
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: skill: writeSkill name (skillContent name skill)) config.skills
        )}
        cp ${hookManifest} "$out/hook-manifest"
        cp ${skillVersionManifest} "$out/skill-versions.json"
      '';

      opencodeOutputs = ''
        ${commonOutputs}
        cp ${builtins.toFile "opencode.json" generated.opencodeJson} "$out/opencode.json"
        cp ${builtins.toFile "AGENTS.md" generated.agentsMd} "$out/AGENTS.md"
      '';

      claudeOutputs = ''
        ${commonOutputs}
        cp ${builtins.toFile "settings.json" generated.settingsJson} "$out/settings.json"
        cp ${builtins.toFile "CLAUDE.md" generated.claudeMd} "$out/CLAUDE.md"
        cp ${builtins.toFile "mcp.json" generated.mcpJson} "$out/.mcp.json"
      '';

      codexOutputs = ''
        ${commonOutputs}
        cp ${builtins.toFile "AGENTS.md" generated.agentsMd} "$out/AGENTS.md"
        cp ${builtins.toFile "mcp.json" generated.mcpJson} "$out/mcp.json"
      '';

      piOutputs = ''
        ${commonOutputs}
        cp ${builtins.toFile "AGENTS.md" generated.agentsMd} "$out/AGENTS.md"
        ${lib.optionalString (generated.extensions != null) ''
          mkdir -p "$out/extensions"
          cp -r "${generated.extensions}"/* "$out/extensions/"
        ''}
        ${lib.optionalString (generated.prompts != null) ''
          mkdir -p "$out/prompts"
          cp -r "${generated.prompts}"/* "$out/prompts/"
        ''}
      '';

      cursorOutputs = ''
        mkdir -p "$out/.cursor/rules"
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: content: ''
            cp ${builtins.toFile "cursor-agent-${name}.mdc" content} "$out/.cursor/rules/agent-${name}.mdc"
          '') generated.agentRules
        )}
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: content: ''
            cp ${builtins.toFile "cursor-skill-${name}.mdc" content} "$out/.cursor/rules/skill-${name}.mdc"
          '') generated.skillRules
        )}
        cp ${builtins.toFile "cursor-mcp.json" generated.mcpJson} "$out/.cursor/mcp.json"
      '';

      ampOutputs = ''
        mkdir -p "$out"
        cp ${hookManifest} "$out/hook-manifest"
        cp ${skillVersionManifest} "$out/skill-versions.json"
        cp ${builtins.toFile "amp.json" generated.ampJson} "$out/amp.json"
        cp ${builtins.toFile "AGENTS.md" generated.agentsMd} "$out/AGENTS.md"
      '';

      outputScript =
        if target == "claude" then
          claudeOutputs
        else if target == "codex" then
          codexOutputs
        else if target == "pi" then
          piOutputs
        else if target == "cursor" then
          cursorOutputs
        else if target == "amp" then
          ampOutputs
        else
          opencodeOutputs;
    in
    pkgs.runCommand "nix-agents-${target}-config" { } ''
      mkdir -p "$out"
      ${outputScript}
    '';

  # Build profile metadata for use with mkWrappedTool.
  # Returns an attrset of profileName -> { storePath, pathPrefixes } for all
  # profiles defined in the evaluated modules. Delegates to mkAgentSystem so
  # there is a single code path for building per-profile store paths.
  mkProfileMeta =
    {
      pkgs,
      modules,
      target,
      src ? null,
      inputs ? { },
    }:
    let
      evaluated = evalModules {
        inherit modules;
        specialArgs = { inherit inputs; };
      };
    in
    lib.mapAttrs (name: profile: {
      storePath = mkAgentSystem {
        inherit
          pkgs
          target
          modules
          src
          inputs
          ;
        profile = name;
      };
      inherit (profile) pathPrefixes;
      # Resolve provider names to full provider objects so mkWrappedTool
      # can generate credential-resolution shell code at build time.
      providers = map (pname: evaluated.config.providers.${pname}) profile.providers;
    }) evaluated.config.profiles;

  # Generate a shell snippet that resolves one provider's credential and
  # exports it as the tool's expected env var. Failures are silent so the
  # wrapper never hard-errors when a credential backend is unavailable.
  #
  # For "sops" the credentialRef must use the format "<file>:<key>" where
  # <file> is the path to the sops-encrypted file and <key> is the attribute
  # name to extract.
  mkCredentialSnippet =
    provider:
    let
      src = provider.credentialSource;
      ref = provider.credentialRef;
      inherit (provider) envVar;
      # All snippets follow the same pattern:
      #   1. Suppress shell trace mode during credential fetch to avoid leaking
      #      values in debug output (set +x / set -x restore).
      #   2. Unset the intermediate variable after export so it doesn't linger.
      wrapCredFetch = fetchExpr: ''
        { _nax_xtrace="''${-//[^x]/}"; set +x; } 2>/dev/null
        _nax_cred=${fetchExpr}
        [ -n "$_nax_cred" ] && export ${envVar}="$_nax_cred"
        unset _nax_cred
        { [ -n "$_nax_xtrace" ] && set -x || true; } 2>/dev/null
      '';
    in
    if src == "env" then
      # ref is the name of the env var to read from; re-export under envVar.
      wrapCredFetch ''"''${${ref}:-}"''
    else if src == "protonpass" then
      wrapCredFetch ''$(protonpass-cli item get "${ref}" --fields password 2>/dev/null) || true''
    else if src == "apple-keychain" then
      wrapCredFetch ''$(security find-generic-password -a "$(id -un)" -s "${ref}" -w 2>/dev/null) || true''
    else
      # sops: credentialRef is "file:key"; split at the first colon.
      # Remaining colons in the key are preserved.
      let
        parts = lib.splitString ":" ref;
        sopsFile = lib.head parts;
        sopsKey = lib.concatStringsSep ":" (lib.tail parts);
      in
      wrapCredFetch ''$(sops --decrypt --extract "[\"${sopsKey}\"]" "${sopsFile}" 2>/dev/null) || true'';

in
{
  inherit mkAgentSystem mkProfileMeta;

  mkWrappedTool =
    {
      pkgs,
      target,
      tool,
      agentSystem,
      # Optional: attrset of profileName -> { storePath: path; pathPrefixes: listOf str; providers: list; }
      # Built with mkProfileMeta. When non-empty the wrapper selects a profile at
      # runtime based on $PWD or a .nix-agents-profile override file, and resolves
      # credentials for that profile before exec-ing the tool.
      profileMeta ? { },
      # Optional: force a specific profile name for runtime namespacing and config
      # selection. When set, cwd-based profile detection is skipped.
      profile ? null,
    }:
    let
      toolBin = if target == "claude" then "${tool}/bin/claude" else "${tool}/bin/${target}";
      binName = target;

      hasProfiles = profileMeta != { };
      forcedProfile = if profile != null then profile else "";
      needsProfileSelection = hasProfiles || profile != null;

      # Sort all (profile, prefix) pairs by descending prefix length so that
      # the longest (most-specific) prefix matches first in the shell case.
      allPrefixes = lib.concatMap (
        name: map (prefix: { inherit name prefix; }) profileMeta.${name}.pathPrefixes
      ) (builtins.attrNames profileMeta);

      sortedPrefixes = lib.sort (
        a: b: builtins.stringLength a.prefix > builtins.stringLength b.prefix
      ) allPrefixes;

      # Expand ~ to literal $HOME so shell case patterns match correctly.
      expandPrefix =
        prefix: if lib.hasPrefix "~/" prefix then "$HOME/${lib.removePrefix "~/" prefix}" else prefix;

      # case arms: path prefix -> profile name
      prefixCaseArms = lib.concatStringsSep "\n" (
        map ({ name, prefix }: "          ${expandPrefix prefix}*) _NAX_PROFILE=${name} ;;") sortedPrefixes
      );

      # case arms: profile name -> store path
      profilePathCaseArms = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: meta: "          ${name}) _NAX_CONFIG=${meta.storePath} ;;") profileMeta
      );

      profileDetectionBlock = lib.optionalString hasProfiles ''
        if [ -z "$_NAX_PROFILE" ]; then
          _d="$PWD"
          while [ "$_d" != "/" ] && [ -n "$_d" ]; do
            if [ -f "$_d/.nix-agents-profile" ]; then
              _NAX_PROFILE=$(cat "$_d/.nix-agents-profile")
              break
            fi
            _d="''${_d%/*}"
          done
          if [ -z "$_NAX_PROFILE" ]; then
            case "$PWD" in
        ${prefixCaseArms}
            esac
          fi
        fi
      '';

      # Emitted at the top of the wrapper when profiles are configured.
      # Sets _NAX_CONFIG to the appropriate store path based on $PWD.
      profileBlock = lib.optionalString needsProfileSelection ''
        _NAX_PROFILE="${forcedProfile}"
        ${profileDetectionBlock}
        case "''${_NAX_PROFILE:-}" in
        ${profilePathCaseArms}
          *) _NAX_CONFIG="${agentSystem}" ;;
        esac
      '';

      # Generate per-profile credential resolution as a case statement.
      # Emitted after profile selection so _NAX_PROFILE is already set.
      credentialBlock =
        let
          mkProfileCredArm =
            name: meta:
            let
              snippets = lib.concatStrings (map mkCredentialSnippet meta.providers);
            in
            lib.optionalString (snippets != "") ''
                ${name})
              ${snippets}    ;;
            '';
          arms = lib.concatStrings (lib.mapAttrsToList mkProfileCredArm profileMeta);
        in
        lib.optionalString (hasProfiles && arms != "") ''
          case "''${_NAX_PROFILE:-}" in
          ${arms}  esac
        '';

      # The config store path used throughout the rest of the wrapper.
      # Statically embedded when there are no profiles, runtime variable when there are.
      nixAgentsConfig = if hasProfiles then "$_NAX_CONFIG" else "${agentSystem}";
    in
    pkgs.writeShellScriptBin binName ''
      ${profileBlock}
      ${credentialBlock}
      _NAX_HOOKS="${nixAgentsConfig}/hook-manifest"
      _NAX_BASE_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      _NAX_BASE_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
      export NAX_PROFILE="''${_NAX_PROFILE:-default}"
      _NAX_TOOL_CONFIG_DIR="$_NAX_BASE_CONFIG_HOME/nix-agents/${target}/profiles/$NAX_PROFILE"
      export NAX_SKILL_VERSIONS="${nixAgentsConfig}/skill-versions.json"
      export NAX_WRAPPER_PID=$$
      _run_hook() {
        local event="$1"
        local json="''${2:-{}}"
        if [ -f "$_NAX_HOOKS" ]; then
          while IFS=: read -r ev script; do
            if [ "$ev" = "$event" ]; then
              printf '%s' "$json" | "$script" || true
            fi
          done < "$_NAX_HOOKS"
        fi
      }
      trap '_run_hook session-end "{}"' EXIT
      _run_hook session-start "{}"
      _sync_link_dir() {
        local source_dir="$1"
        local target_path="$2"
        rm -rf "$target_path"
        if [ -d "$source_dir" ]; then
          ln -sfn "$source_dir" "$target_path"
        fi
      }
      _sync_link_file() {
        local source_file="$1"
        local target_path="$2"
        rm -rf "$target_path"
        if [ -f "$source_file" ]; then
          ln -sfn "$source_file" "$target_path"
        fi
      }

      if [ "${target}" = "opencode" ]; then
        mkdir -p "$_NAX_TOOL_CONFIG_DIR"
        _sync_link_dir "${nixAgentsConfig}/agents" "$_NAX_TOOL_CONFIG_DIR/agents"
        _sync_link_dir "${nixAgentsConfig}/skills" "$_NAX_TOOL_CONFIG_DIR/skills"
        _sync_link_file "${nixAgentsConfig}/AGENTS.md" "$_NAX_TOOL_CONFIG_DIR/AGENTS.md"
        _sync_link_file "${nixAgentsConfig}/opencode.json" "$_NAX_TOOL_CONFIG_DIR/opencode.json"
        if [ -n "''${_NAX_PROFILE:-}" ]; then
          export XDG_CONFIG_HOME="$_NAX_BASE_CONFIG_HOME/opencode/profiles/$_NAX_PROFILE"
          export XDG_DATA_HOME="$_NAX_BASE_DATA_HOME/opencode/profiles/$_NAX_PROFILE"
          mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
        fi
        export OPENCODE_CONFIG="$_NAX_TOOL_CONFIG_DIR/opencode.json"
        export OPENCODE_CONFIG_DIR="$_NAX_TOOL_CONFIG_DIR"
        export OPENCODE_CONFIG_CONTENT='{"autoupdate":false}'
      fi

      if [ "${target}" = "claude" ]; then
        _nix_agents_dir="$_NAX_BASE_CONFIG_HOME/nix-agents/claude/profiles/$NAX_PROFILE"
        mkdir -p "$_nix_agents_dir"
        _sync_link_dir "${nixAgentsConfig}/agents" "$_nix_agents_dir/agents"
        _sync_link_dir "${nixAgentsConfig}/skills" "$_nix_agents_dir/skills"
        _sync_link_file "${nixAgentsConfig}/CLAUDE.md" "$_nix_agents_dir/CLAUDE.md"
        _sync_link_file "${nixAgentsConfig}/settings.json" "$_nix_agents_dir/settings.json"
        _sync_link_file "${nixAgentsConfig}/.mcp.json" "$_nix_agents_dir/.mcp.json"
        export CLAUDE_CONFIG_DIR="$_nix_agents_dir"
        set -- --settings "$_nix_agents_dir/settings.json" "$@"
        [ -f "$_nix_agents_dir/.mcp.json" ] && set -- --mcp-config "$_nix_agents_dir/.mcp.json" "$@"
        exec "${toolBin}" "$@"
      fi

      if [ "${target}" = "codex" ]; then
        _nix_agents_dir="$_NAX_BASE_CONFIG_HOME/nix-agents/codex/profiles/$NAX_PROFILE"
        mkdir -p "$_nix_agents_dir"
        _sync_link_dir "${nixAgentsConfig}/agents" "$_nix_agents_dir/agents"
        _sync_link_dir "${nixAgentsConfig}/skills" "$_nix_agents_dir/skills"
        _sync_link_file "${nixAgentsConfig}/AGENTS.md" "$_nix_agents_dir/AGENTS.md"
        _sync_link_file "${nixAgentsConfig}/mcp.json" "$_nix_agents_dir/mcp.json"
        export CODEX_CONFIG_DIR="$_nix_agents_dir"
        exec "${toolBin}" "$@"
      fi

      if [ "${target}" = "pi" ]; then
        _nix_agents_dir="$_NAX_BASE_CONFIG_HOME/nix-agents/pi/profiles/$NAX_PROFILE"
        _pi_agent_dir="$HOME/.pi/agent"
        mkdir -p "$_nix_agents_dir" "$_pi_agent_dir"
        _sync_link_dir "${nixAgentsConfig}/agents" "$_nix_agents_dir/agents"
        _sync_link_dir "${nixAgentsConfig}/skills" "$_nix_agents_dir/skills"
        _sync_link_file "${nixAgentsConfig}/AGENTS.md" "$_nix_agents_dir/AGENTS.md"
        _sync_link_dir "${nixAgentsConfig}/extensions" "$_nix_agents_dir/extensions"
        _sync_link_dir "${nixAgentsConfig}/prompts" "$_nix_agents_dir/prompts"
        _sync_link_dir "$_nix_agents_dir/agents" "$_pi_agent_dir/agents"
        _sync_link_dir "$_nix_agents_dir/skills" "$_pi_agent_dir/skills"
        _sync_link_file "$_nix_agents_dir/AGENTS.md" "$_pi_agent_dir/AGENTS.md"
        _sync_link_dir "$_nix_agents_dir/extensions" "$_pi_agent_dir/extensions"
        _sync_link_dir "$_nix_agents_dir/prompts" "$_pi_agent_dir/prompts"
        if [ -n "''${_NAX_PROFILE:-}" ]; then
          export XDG_CONFIG_HOME="$_NAX_BASE_CONFIG_HOME/pi/profiles/$_NAX_PROFILE"
          export XDG_DATA_HOME="$_NAX_BASE_DATA_HOME/pi/profiles/$_NAX_PROFILE"
          mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
        fi
        exec "${toolBin}" "$@"
      fi

      exec "${toolBin}" "$@"
    '';
}
