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

  # Normalize a profile identifier into { base, profile }.
  # Accepts both "<base>/<profile>" and flat names ("<profile>").
  # Flat names are resolved to "<profile>.base" if set, otherwise "default/<profile>".
  resolveBaseProfile =
    config: profileName:
    let
      parts = lib.splitString "/" profileName;
    in
    if builtins.length parts > 1 then
      # Explicit <base>/<profile> format
      {
        base = lib.head parts;
        profile = lib.concatStringsSep "/" (lib.tail parts);
      }
    else
      # Flat name — profile must declare a base field
      let
        profileCfg = config.profiles.${profileName} or null;
        baseName =
          if profileCfg != null && profileCfg.base != null then
            profileCfg.base
          else
            throw "nix-agents: profile '${profileName}' has no base assigned. "
            + "Every profile must declare a base field referencing an entry in config.bases.";
      in
      {
        base = baseName;
        profile = profileName;
      };

  # Resolve a named profile against the full config, returning a filtered/overridden config.
  # Base-aware: merges base-scoped providers, human, and pathPrefixes when applicable.
  resolveProfile =
    config: profileName:
    let
      resolved = resolveBaseProfile config profileName;
      baseCfg = config.bases.${resolved.base} or null;
      profile = config.profiles.${profileName};

      filterByWhitelist =
        whitelist: attrset:
        if whitelist == [ ] then
          attrset
        else
          lib.filterAttrs (name: _: builtins.elem name whitelist) attrset;

      # Merge base + profile providers (profile adds to base, deduped)
      baseProviders = if baseCfg != null then baseCfg.providers else [ ];
      mergedProviderNames = lib.unique (baseProviders ++ profile.providers);

      # Human resolution: profile > base > system
      resolvedHuman =
        if profile.human != null then
          profile.human
        else if baseCfg != null && baseCfg.human != null then
          baseCfg.human
        else
          config.human;

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
      # Expose the resolved base name and merged provider list for downstream consumers.
      # These are used by mkProfileMeta and mkWrappedTool for base-scoped state.
      _resolvedBase = resolved.base;
      _resolvedProviders = mergedProviderNames;
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
        specialArgs = { inherit inputs pkgs; };
      };
      rawConfig = evaluated.config;
      config =
        if rawConfig._validated then
          if profile != null then resolveProfile rawConfig profile else rawConfig
        else
          throw "nix-agents validation failed";
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

      # Build full SKILL.md content: prepend YAML frontmatter with name and description
      # when skill is defined inline (not via src). This ensures Pi can discover
      # and load the skill.
      mkSkillContent =
        name: skill:
        let
          yamlEscape =
            s:
            lib.replaceStrings
              [
                "\\"
                "\""
                "\n"
                "\r"
              ]
              [
                "\\\\"
                "\\\""
                "\\n"
                ""
              ]
              s;
          frontmatter = ''
            ---
            name: "${yamlEscape name}"
            description: "${yamlEscape skill.description}"
            ---
          '';
        in
        if skill.content == "" then
          # No content (e.g., skill uses src directly) — use empty body
          frontmatter
        else
          frontmatter + "\n" + skill.content;

      writeSkill =
        name: skill:
        if skill.src != null then
          ''
            mkdir -p "$out/skills/${name}"
            cp -r ${skill.src}/. "$out/skills/${name}/"
            chmod -R u+w "$out/skills/${name}"
          ''
        else
          ''
            mkdir -p "$out/skills/${name}"
            cp ${builtins.toFile "skill-${name}.md" (mkSkillContent name skill)} "$out/skills/${name}/SKILL.md"
          '';

      commonOutputs = ''
        mkdir -p "$out/agents" "$out/skills"
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList writeAgent generated.agents)}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList writeSkill config.skills)}
        cp ${hookManifest} "$out/hook-manifest"
        cp ${skillVersionManifest} "$out/skill-versions.json"
      '';

      opencodeOutputs = ''
        ${commonOutputs}
        cp ${pkgs.writeText "opencode.json" generated.opencodeJson} "$out/opencode.json"
        cp ${builtins.toFile "AGENTS.md" generated.agentsMd} "$out/AGENTS.md"
      '';

      claudeOutputs = ''
        ${commonOutputs}
        cp ${builtins.toFile "settings.json" generated.settingsJson} "$out/settings.json"
        cp ${builtins.toFile "CLAUDE.md" generated.claudeMd} "$out/CLAUDE.md"
        cp ${pkgs.writeText "mcp.json" generated.mcpJson} "$out/.mcp.json"
      '';

      codexOutputs = ''
        ${commonOutputs}
        cp ${builtins.toFile "AGENTS.md" generated.agentsMd} "$out/AGENTS.md"
        cp ${pkgs.writeText "mcp.nix.toml" generated.mcpToml} "$out/mcp.nix.toml"
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
        cp ${pkgs.writeText "cursor-mcp.json" generated.mcpJson} "$out/.cursor/mcp.json"
      '';

      ampOutputs = ''
        mkdir -p "$out"
        cp ${hookManifest} "$out/hook-manifest"
        cp ${skillVersionManifest} "$out/skill-versions.json"
        cp ${pkgs.writeText "amp.json" generated.ampJson} "$out/amp.json"
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
  # Returns an attrset of profileName -> { storePath, pathPrefixes, providers, base }
  # for all profiles defined in the evaluated modules.
  # Delegates to mkAgentSystem so there is a single code path for building
  # per-profile store paths.
  #
  # Each entry includes:
  #   storePath    — nix store path with generated config
  #   pathPrefixes — filesystem prefixes for profile auto-detection
  #   providers    — resolved provider objects (base + profile merged, deduped)
  #   base         — resolved base name from profile's base field
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
        specialArgs = { inherit inputs pkgs; };
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
      pathPrefixes =
        let
          # Merge base pathPrefixes + profile pathPrefixes
          baseCfg = evaluated.config.bases.${(resolveBaseProfile evaluated.config name).base} or null;
          basePrefixes = if baseCfg != null then baseCfg.pathPrefixes else [ ];
        in
        lib.unique (basePrefixes ++ profile.pathPrefixes);
      # Resolve providers: merge base + profile provider names, dedupe, then
      # resolve to full provider objects for mkWrappedTool credential generation.
      providers =
        let
          baseCfg = evaluated.config.bases.${(resolveBaseProfile evaluated.config name).base} or null;
          baseProviderNames = if baseCfg != null then baseCfg.providers else [ ];
          mergedNames = lib.unique (baseProviderNames ++ profile.providers);
        in
        map (pname: evaluated.config.providers.${pname}) mergedNames;
      # Resolve git identity from base.
      git =
        let
          baseCfg = evaluated.config.bases.${(resolveBaseProfile evaluated.config name).base} or null;
        in
        if baseCfg != null && baseCfg.git != null then baseCfg.git else null;
      sandbox = if profile.sandbox != null then evaluated.config.sandboxes.${profile.sandbox} else null;
      inherit ((resolveBaseProfile evaluated.config name)) base;
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
    else if src == "file" then
      # ref is a plaintext file path containing the credential.
      wrapCredFetch ''$(tr -d '[:space:]' < "${ref}" 2>/dev/null) || true''
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
  inherit mkAgentSystem mkProfileMeta resolveBaseProfile;

  mkWrappedTool =
    {
      pkgs,
      target,
      tool,
      agentSystem,
      openshell ? pkgs.openshell,
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
      boolFlag = value: if value then "1" else "0";

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

      # case arms: profile name -> (base, store path)
      profilePathCaseArms = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: meta: "          ${name}) _NAX_CONFIG=${meta.storePath}; _NAX_BASE=\"${meta.base}\" ;;"
        ) profileMeta
      );

      # Deterministic fallback when no profile is detected.
      # Prefer personal-default when available so personal projects outside
      # known prefixes still get a valid base/profile config path.
      fallbackProfileName =
        if hasProfiles && profileMeta ? "personal-default" then
          "personal-default"
        else if hasProfiles && profileMeta ? "personal-stable" then
          "personal-stable"
        else if hasProfiles then
          lib.head (builtins.attrNames profileMeta)
        else
          null;

      fallbackProfileMeta =
        if fallbackProfileName != null then profileMeta.${fallbackProfileName} else null;

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
      # Sets _NAX_CONFIG and _NAX_BASE based on $PWD.
      profileBlock = lib.optionalString needsProfileSelection ''
        _NAX_PROFILE="${forcedProfile}"
        ${profileDetectionBlock}
        case "''${_NAX_PROFILE:-}" in
        ${profilePathCaseArms}
          *)
            ${lib.optionalString (fallbackProfileMeta != null) ''
              _NAX_PROFILE="${fallbackProfileName}"
              _NAX_CONFIG=${fallbackProfileMeta.storePath}
              _NAX_BASE="${fallbackProfileMeta.base}"
            ''}
            ${lib.optionalString (fallbackProfileMeta == null) ''
              _NAX_CONFIG="${agentSystem}"
            ''}
            ;;
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

      # Generate per-profile git identity exports as a case statement.
      # Sets GIT_AUTHOR/COMMITTER env vars so commits from subagents use the
      # correct identity for the active base.
      gitIdentityBlock =
        let
          mkGitArm =
            name: meta:
            lib.optionalString (meta.git != null) ''
              ${name})
                export GIT_AUTHOR_NAME="${meta.git.userName}"
                export GIT_AUTHOR_EMAIL="${meta.git.userEmail}"
                export GIT_COMMITTER_NAME="${meta.git.userName}"
                export GIT_COMMITTER_EMAIL="${meta.git.userEmail}"
                ${lib.optionalString (meta.git.signingKey != null) ''
                  export GIT_AUTHOR_SIGNINGKEY="${meta.git.signingKey}"
                  export GIT_COMMITTER_SIGNINGKEY="${meta.git.signingKey}"
                ''}
                ;;
            '';
          arms = lib.concatStrings (lib.mapAttrsToList mkGitArm profileMeta);
        in
        lib.optionalString (hasProfiles && arms != "") ''
          case "''${_NAX_PROFILE:-}" in
          ${arms}  esac
        '';

      sandboxBlock =
        let
          appendArg = arg: ''
            _NAX_SANDBOX_ARGS+=(${lib.escapeShellArg arg})
          '';
          appendArgValue = flag: value: ''
            _NAX_SANDBOX_ARGS+=(${lib.escapeShellArg flag} ${lib.escapeShellArg value})
          '';
          appendStringList = flag: values: lib.concatMapStrings (value: appendArgValue flag value) values;
          mkSandboxArm =
            name: meta:
            let
              inherit (meta) sandbox;
            in
            lib.optionalString (sandbox != null) ''
              ${name})
                _NAX_SANDBOX_ENABLED=1
                _NAX_SANDBOX_UPLOAD_PROFILE_CONFIG=${boolFlag sandbox.uploadProfileConfig}
                _NAX_SANDBOX_UPLOAD_PROJECT=${boolFlag sandbox.uploadProject}
                _NAX_SANDBOX_USE_GITIGNORE=${boolFlag sandbox.useGitIgnore}
                ${lib.optionalString (sandbox.command != null) ''
                  _NAX_SANDBOX_COMMAND=${lib.escapeShellArg sandbox.command}
                ''}
                ${lib.optionalString (sandbox.from != null) (appendArgValue "--from" sandbox.from)}
                ${lib.optionalString (!sandbox.keep) (appendArg "--no-keep")}
                ${lib.optionalString sandbox.gpu (appendArg "--gpu")}
                ${appendStringList "--provider" sandbox.providers}
                ${lib.optionalString (sandbox.policy != null) (appendArgValue "--policy" "${sandbox.policy}")}
                ${appendStringList "--forward" sandbox.forward}
                ${lib.optionalString (sandbox.autoProviders != null) (
                  if sandbox.autoProviders then appendArg "--auto-providers" else appendArg "--no-auto-providers"
                )}
                ${lib.optionalString (sandbox.tty != null) (
                  if sandbox.tty then appendArg "--tty" else appendArg "--no-tty"
                )}
                ${lib.optionalString sandbox.noBootstrap (appendArg "--no-bootstrap")}
                ${lib.optionalString (sandbox.remote != null) (appendArgValue "--remote" sandbox.remote)}
                ${lib.optionalString (sandbox.sshKey != null) (appendArgValue "--ssh-key" sandbox.sshKey)}
                ${lib.concatMapStrings appendArg sandbox.extraArgs}
                ;;
            '';
          arms = lib.concatStrings (lib.mapAttrsToList mkSandboxArm profileMeta);
        in
        lib.optionalString (hasProfiles && arms != "") ''
          _NAX_SANDBOX_ENABLED=0
          _NAX_SANDBOX_COMMAND=""
          _NAX_SANDBOX_PROFILE_CONFIG_DIR=""
          _NAX_SANDBOX_REMOTE_CONFIG_DIR=".nix-agents-profile-config"
          _NAX_SANDBOX_REMOTE_CONFIG_REF="../.nix-agents-profile-config"
          _NAX_SANDBOX_REMOTE_DATA_DIR=".nix-agents-data"
          _NAX_SANDBOX_REMOTE_DATA_REF="../.nix-agents-data"
          _NAX_SANDBOX_REMOTE_PROJECT_DIR=".nix-agents-project"
          _NAX_SANDBOX_UPLOAD_PROFILE_CONFIG=1
          _NAX_SANDBOX_UPLOAD_PROJECT=1
          _NAX_SANDBOX_USE_GITIGNORE=1
          _NAX_SANDBOX_ARGS=()
          _NAX_SANDBOX_REMOTE_ENV=()
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
      ${gitIdentityBlock}
      ${sandboxBlock}
      _NAX_HOOKS="${nixAgentsConfig}/hook-manifest"
      _NAX_BASE_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      _NAX_BASE_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
      export NAX_PROFILE="''${_NAX_PROFILE:-default}"
      export NAX_BASE="$_NAX_BASE"
      _NAX_TOOL_CONFIG_DIR="$_NAX_BASE_CONFIG_HOME/nix-agents/${target}/bases/$NAX_BASE/profiles/$NAX_PROFILE"
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
        if [ -e "$target_path" ]; then
          chmod -R u+w "$target_path" 2>/dev/null || true
        fi
        rm -rf "$target_path"
        if [ -d "$source_dir" ]; then
          mkdir -p "$target_path"
          cp -R "$source_dir"/. "$target_path"/
          chmod -R u+w "$target_path"
        fi
      }
      _sync_link_file() {
        local source_file="$1"
        local target_path="$2"
        if [ -e "$target_path" ]; then
          chmod u+w "$target_path" 2>/dev/null || true
        fi
        rm -rf "$target_path"
        if [ -f "$source_file" ]; then
          cp "$source_file" "$target_path"
          chmod u+w "$target_path"
        fi
      }

      # Symlink persisted base-scoped settings files into the profile directory
      # and source environment overrides.
      # Files live at ~/.config/nix-agents/<tool>/bases/<base>/settings/ and survive
      # nix store syncs. This lets users maintain per-base overrides (e.g. EU API
      # endpoints for work bases) without them being wiped on each launch.
      #
      # Regular files are symlinked into the profile directory.
      # An "env" file is sourced (not symlinked) to export environment variables
      # like OPENAI_BASE_URL. It should contain lines of the form:
      #   export VAR=value
      _link_base_settings() {
        local _settings_dir="$1"
        local _profile_dir="$2"
        if [ -d "$_settings_dir" ]; then
          # Source env file first so exports are available before tool launch
          if [ -f "$_settings_dir/env" ]; then
            . "$_settings_dir/env"
          fi
          for _f in "$_settings_dir"/*; do
            [ -f "$_f" ] || continue
            _name="''${_f##*/}"
            # env is sourced, not symlinked
            [ "$_name" = "env" ] && continue
            ln -sfn "$_f" "$_profile_dir/$_name" 2>/dev/null || true
          done
        fi
      }
      _link_base_settings_except_config_toml() {
        local _settings_dir="$1"
        local _profile_dir="$2"
        if [ -d "$_settings_dir" ]; then
          # Source env file first so exports are available before tool launch
          if [ -f "$_settings_dir/env" ]; then
            . "$_settings_dir/env"
          fi
          for _f in "$_settings_dir"/*; do
            [ -f "$_f" ] || continue
            _name="''${_f##*/}"
            # env is sourced, not symlinked. config.toml is merged with generated
            # Codex MCP config rather than symlinked directly.
            [ "$_name" = "env" ] && continue
            [ "$_name" = "config.toml" ] && continue
            ln -sfn "$_f" "$_profile_dir/$_name" 2>/dev/null || true
          done
        fi
      }
      _merge_codex_config() {
        local user_config="$1"
        local nix_mcp_config="$2"
        local target_config="$3"

        rm -f "$target_config"

        if [ -f "$user_config" ]; then
          cat "$user_config" >> "$target_config"
        fi

        if [ -s "$nix_mcp_config" ]; then
          if [ -s "$target_config" ]; then
            printf '\n' >> "$target_config"
          fi
          cat "$nix_mcp_config" >> "$target_config"
        fi

        if [ -e "$target_config" ]; then
          chmod u+w "$target_config"
        fi
      }
      _NAX_SANDBOX_DEFAULT_COMMAND="${target}"
      _nax_exec_tool() {
        local _local_tool="$1"
        shift
        if [ "''${_NAX_SANDBOX_ENABLED:-0}" = "1" ]; then
          local _nax_stage
          _nax_stage="$(mktemp -d "''${TMPDIR:-/tmp}/nix-agents-openshell.XXXXXX")"
          local -a _nax_args
          local -a _nax_env
          _nax_args=(sandbox create)
          _nax_args+=("''${_NAX_SANDBOX_ARGS[@]}")
          mkdir -p "$_nax_stage/$_NAX_SANDBOX_REMOTE_PROJECT_DIR"
          if [ "''${_NAX_SANDBOX_UPLOAD_PROFILE_CONFIG:-1}" = "1" ] && [ -n "''${_NAX_SANDBOX_PROFILE_CONFIG_DIR:-}" ]; then
            mkdir -p "$_nax_stage/$_NAX_SANDBOX_REMOTE_CONFIG_DIR"
            ${pkgs.rsync}/bin/rsync -a "$_NAX_SANDBOX_PROFILE_CONFIG_DIR"/ "$_nax_stage/$_NAX_SANDBOX_REMOTE_CONFIG_DIR"/
          fi
          if [ "''${_NAX_SANDBOX_UPLOAD_PROJECT:-1}" = "1" ]; then
            if [ "''${_NAX_SANDBOX_USE_GITIGNORE:-1}" = "1" ]; then
              ${pkgs.rsync}/bin/rsync -a --exclude '.git/' --filter=':- .gitignore' "$PWD"/ "$_nax_stage/$_NAX_SANDBOX_REMOTE_PROJECT_DIR"/
            else
              ${pkgs.rsync}/bin/rsync -a --exclude '.git/' "$PWD"/ "$_nax_stage/$_NAX_SANDBOX_REMOTE_PROJECT_DIR"/
            fi
          fi
          _nax_args+=(--upload "$_nax_stage")
          _nax_env=(
            "NAX_PROFILE=$NAX_PROFILE"
            "NAX_BASE=$NAX_BASE"
            "NAX_SKILL_VERSIONS=$NAX_SKILL_VERSIONS"
          )
          _nax_env+=("''${_NAX_SANDBOX_REMOTE_ENV[@]}")
          "${openshell}/bin/openshell" "''${_nax_args[@]}" -- sh -lc 'cd "$1" && shift && exec env "$@"' sh "$_NAX_SANDBOX_REMOTE_PROJECT_DIR" "''${_nax_env[@]}" "''${_NAX_SANDBOX_COMMAND:-$_NAX_SANDBOX_DEFAULT_COMMAND}" "$@"
          local _nax_status=$?
          rm -rf "$_nax_stage"
          exit "$_nax_status"
        fi
        exec "$_local_tool" "$@"
      }

      if [ "${target}" = "opencode" ]; then
        mkdir -p "$_NAX_TOOL_CONFIG_DIR"
        _sync_link_dir "${nixAgentsConfig}/agents" "$_NAX_TOOL_CONFIG_DIR/agents"
        _sync_link_dir "${nixAgentsConfig}/skills" "$_NAX_TOOL_CONFIG_DIR/skills"
        _sync_link_file "${nixAgentsConfig}/AGENTS.md" "$_NAX_TOOL_CONFIG_DIR/AGENTS.md"
        _sync_link_file "${nixAgentsConfig}/opencode.json" "$_NAX_TOOL_CONFIG_DIR/opencode.json"
        _link_base_settings "$_NAX_BASE_CONFIG_HOME/nix-agents/opencode/bases/$NAX_BASE/settings" "$_NAX_TOOL_CONFIG_DIR"
        if [ -n "''${_NAX_PROFILE:-}" ]; then
          export XDG_CONFIG_HOME="$_NAX_BASE_CONFIG_HOME/opencode/bases/$NAX_BASE/profiles/$_NAX_PROFILE"
          export XDG_DATA_HOME="$_NAX_BASE_DATA_HOME/opencode/bases/$NAX_BASE/profiles/$_NAX_PROFILE"
          mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
        fi
        export OPENCODE_CONFIG="$_NAX_TOOL_CONFIG_DIR/opencode.json"
        export OPENCODE_CONFIG_DIR="$_NAX_TOOL_CONFIG_DIR"
        export OPENCODE_CONFIG_CONTENT='{"autoupdate":false}'
        _NAX_SANDBOX_PROFILE_CONFIG_DIR="$_NAX_TOOL_CONFIG_DIR"
        _NAX_SANDBOX_REMOTE_ENV+=(
          "XDG_CONFIG_HOME=$_NAX_SANDBOX_REMOTE_CONFIG_REF"
          "XDG_DATA_HOME=$_NAX_SANDBOX_REMOTE_DATA_REF"
          "OPENCODE_CONFIG=$_NAX_SANDBOX_REMOTE_CONFIG_REF/opencode.json"
          "OPENCODE_CONFIG_DIR=$_NAX_SANDBOX_REMOTE_CONFIG_REF"
          "OPENCODE_CONFIG_CONTENT=$OPENCODE_CONFIG_CONTENT"
        )
      fi

      if [ "${target}" = "claude" ]; then
        _nix_agents_dir="$_NAX_BASE_CONFIG_HOME/nix-agents/claude/bases/$NAX_BASE/profiles/$NAX_PROFILE"
        mkdir -p "$_nix_agents_dir"
        _sync_link_dir "${nixAgentsConfig}/agents" "$_nix_agents_dir/agents"
        _sync_link_dir "${nixAgentsConfig}/skills" "$_nix_agents_dir/skills"
        _sync_link_file "${nixAgentsConfig}/CLAUDE.md" "$_nix_agents_dir/CLAUDE.md"
        _sync_link_file "${nixAgentsConfig}/settings.json" "$_nix_agents_dir/settings.json"
        _sync_link_file "${nixAgentsConfig}/.mcp.json" "$_nix_agents_dir/.mcp.json"
        _link_base_settings "$_NAX_BASE_CONFIG_HOME/nix-agents/claude/bases/$NAX_BASE/settings" "$_nix_agents_dir"
        export CLAUDE_CONFIG_DIR="$_nix_agents_dir"
        _NAX_SANDBOX_PROFILE_CONFIG_DIR="$_nix_agents_dir"
        _NAX_SANDBOX_REMOTE_ENV+=("CLAUDE_CONFIG_DIR=$_NAX_SANDBOX_REMOTE_CONFIG_REF")
        if [ "''${_NAX_SANDBOX_ENABLED:-0}" = "1" ]; then
          set -- --settings "$_NAX_SANDBOX_REMOTE_CONFIG_REF/settings.json" "$@"
          [ -f "$_nix_agents_dir/.mcp.json" ] && set -- --mcp-config "$_NAX_SANDBOX_REMOTE_CONFIG_REF/.mcp.json" "$@"
        else
          set -- --settings "$_nix_agents_dir/settings.json" "$@"
          [ -f "$_nix_agents_dir/.mcp.json" ] && set -- --mcp-config "$_nix_agents_dir/.mcp.json" "$@"
        fi
        _nax_exec_tool "${toolBin}" "$@"
      fi

      if [ "${target}" = "codex" ]; then
        _nix_agents_dir="$_NAX_BASE_CONFIG_HOME/nix-agents/codex/bases/$NAX_BASE/profiles/$NAX_PROFILE"
        mkdir -p "$_nix_agents_dir"
        _sync_link_dir "${nixAgentsConfig}/agents" "$_nix_agents_dir/agents"
        _sync_link_dir "${nixAgentsConfig}/skills" "$_nix_agents_dir/skills"
        _sync_link_file "${nixAgentsConfig}/AGENTS.md" "$_nix_agents_dir/AGENTS.md"
        _sync_link_file "${nixAgentsConfig}/mcp.nix.toml" "$_nix_agents_dir/mcp.nix.toml"
        _link_base_settings_except_config_toml "$_NAX_BASE_CONFIG_HOME/nix-agents/codex/bases/$NAX_BASE/settings" "$_nix_agents_dir"
        _merge_codex_config "$_NAX_BASE_CONFIG_HOME/nix-agents/codex/bases/$NAX_BASE/settings/config.toml" "$_nix_agents_dir/mcp.nix.toml" "$_nix_agents_dir/config.toml"
        export CODEX_HOME="$_nix_agents_dir"
        _NAX_SANDBOX_PROFILE_CONFIG_DIR="$_nix_agents_dir"
        _NAX_SANDBOX_REMOTE_ENV+=("CODEX_HOME=$_NAX_SANDBOX_REMOTE_CONFIG_REF")
        _nax_exec_tool "${toolBin}" "$@"
      fi

      if [ "${target}" = "pi" ]; then
        _pi_base_dir="$_NAX_BASE_CONFIG_HOME/nix-agents/pi/bases/$NAX_BASE"
        _pi_profile_dir="$_pi_base_dir/profiles/$NAX_PROFILE"
        _pi_state_dir="$_pi_base_dir/state"
        mkdir -p "$_pi_profile_dir" "$_pi_state_dir"

        # Profile-specific content from nix store
        _sync_link_dir "${nixAgentsConfig}/agents" "$_pi_profile_dir/agents"
        _sync_link_dir "${nixAgentsConfig}/skills" "$_pi_profile_dir/skills"
        _sync_link_file "${nixAgentsConfig}/AGENTS.md" "$_pi_profile_dir/AGENTS.md"
        _sync_link_dir "${nixAgentsConfig}/extensions" "$_pi_profile_dir/extensions"
        _sync_link_dir "${nixAgentsConfig}/prompts" "$_pi_profile_dir/prompts"

        # Shared state from base-scoped state dir (credentials, sessions, models, settings)
        if [ ! -e "$_pi_profile_dir/auth.json" ]; then
          ln -sfn "$_pi_state_dir/auth.json" "$_pi_profile_dir/auth.json" 2>/dev/null || true
        fi
        if [ ! -e "$_pi_profile_dir/models.json" ]; then
          ln -sfn "$_pi_state_dir/models.json" "$_pi_profile_dir/models.json" 2>/dev/null || true
        fi
        if [ ! -e "$_pi_profile_dir/settings.json" ]; then
          ln -sfn "$_pi_state_dir/settings.json" "$_pi_profile_dir/settings.json" 2>/dev/null || true
        fi
        _sync_link_dir "$_pi_state_dir/sessions" "$_pi_profile_dir/sessions"

        _link_base_settings "$_NAX_BASE_CONFIG_HOME/nix-agents/pi/bases/$NAX_BASE/settings" "$_pi_profile_dir"

        export PI_CODING_AGENT_DIR="$_pi_profile_dir"
        _NAX_SANDBOX_PROFILE_CONFIG_DIR="$_pi_profile_dir"
        _NAX_SANDBOX_REMOTE_ENV+=("PI_CODING_AGENT_DIR=$_NAX_SANDBOX_REMOTE_CONFIG_REF")
        _nax_exec_tool "${toolBin}" "$@"
      fi

      _nax_exec_tool "${toolBin}" "$@"
    '';
}
