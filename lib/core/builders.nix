{ lib, evalModules }:
let
  opencodeGenerator = import ../generators/opencode.nix;
  claudeCodeGenerator = import ../generators/claude-code.nix;
  codexGenerator = import ../generators/codex.nix;
  piGenerator = import ../generators/pi.nix;

  mkGenerator =
    target:
    if target == "claude" then
      claudeCodeGenerator
    else if target == "codex" then
      codexGenerator
    else if target == "pi" then
      piGenerator
    else
      opencodeGenerator;
in
{
  mkAgentSystem =
    {
      pkgs,
      modules ? [ ],
      target ? "opencode",
      src ? null,
      inputs ? { },
    }:
    let
      evaluated = evalModules {
        inherit modules;
        specialArgs = { inherit inputs; };
      };
      inherit (evaluated) config;
      generated = mkGenerator target { inherit lib config src; };

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

      outputScript =
        if target == "claude" then
          claudeOutputs
        else if target == "codex" then
          codexOutputs
        else if target == "pi" then
          piOutputs
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
