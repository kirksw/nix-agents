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
in
{
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

      hookManifest = builtins.toFile "hook-manifest" (
        lib.concatMapStringsSep "\n" (hook: "${hook.event}:${hook.command}") config.hooks
      );

      writeAgent = name: content: ''
        cp ${builtins.toFile "agent-${name}.md" content} "$out/agents/${name}.md"
      '';

      skillContent =
        name: skill:
        if skill.src != null then builtins.readFile (skill.src + "/SKILL.md") else skill.content;

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
        echo "Codex generator is experimental. Output format may change." > "$out/EXPERIMENTAL"
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
        echo "Cursor generator is experimental. Output format may change." > "$out/EXPERIMENTAL"
      '';

      ampOutputs = ''
        cp ${builtins.toFile "amp.json" generated.ampJson} "$out/amp.json"
        cp ${builtins.toFile "AGENTS.md" generated.agentsMd} "$out/AGENTS.md"
        echo "Amp generator is experimental. Output format may change." > "$out/EXPERIMENTAL"
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

  mkWrappedTool =
    {
      pkgs,
      target,
      tool,
      agentSystem,
    }:
    let
      toolBin = if target == "claude" then "${tool}/bin/claude" else "${tool}/bin/${target}";
      binName = target;
    in
    pkgs.writeShellScriptBin binName ''
      _NAX_HOOKS="${agentSystem}/hook-manifest"
      _run_hook() {
        local event="$1"
        local json="''${2:-{}}"
        if [ -f "$_NAX_HOOKS" ]; then
          while IFS=: read -r ev cmd; do
            if [ "$ev" = "$event" ]; then
              printf '%s' "$json" | eval "$cmd" || true
            fi
          done < "$_NAX_HOOKS"
        fi
      }
      trap '_run_hook session-end "{}"' EXIT
      _run_hook session-start "{}"

      if [ "${target}" = "opencode" ]; then
        export OPENCODE_CONFIG="${agentSystem}/opencode.json"
        export OPENCODE_CONFIG_DIR="${agentSystem}"
        export OPENCODE_CONFIG_CONTENT='{"autoupdate":false}'
      fi

      if [ "${target}" = "claude" ]; then
        _nix_agents_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/claude"
        mkdir -p "$_nix_agents_dir"
        ln -sfn "${agentSystem}/agents" "$_nix_agents_dir/agents"
        ln -sfn "${agentSystem}/skills" "$_nix_agents_dir/skills"
        [ -f "${agentSystem}/CLAUDE.md" ] && ln -sfn "${agentSystem}/CLAUDE.md" "$_nix_agents_dir/CLAUDE.md"
        export CLAUDE_CONFIG_DIR="$_nix_agents_dir"
        set -- --settings "${agentSystem}/settings.json" "$@"
        [ -f "${agentSystem}/.mcp.json" ] && set -- --mcp-config "${agentSystem}/.mcp.json" "$@"
        exec "${toolBin}" "$@"
      fi

      if [ "${target}" = "codex" ]; then
        _nix_agents_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/codex"
        mkdir -p "$_nix_agents_dir"
        ln -sfn "${agentSystem}/agents" "$_nix_agents_dir/agents"
        ln -sfn "${agentSystem}/skills" "$_nix_agents_dir/skills"
        [ -f "${agentSystem}/AGENTS.md" ] && ln -sfn "${agentSystem}/AGENTS.md" "$_nix_agents_dir/AGENTS.md"
        export CODEX_CONFIG_DIR="$_nix_agents_dir"
        exec "${toolBin}" "$@"
      fi

      exec "${toolBin}" "$@"
    '';
}
