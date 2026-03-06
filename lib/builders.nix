{ lib, evalModules }:
let
  opencodeGenerator = import ./generators/opencode.nix;
  claudeCodeGenerator = import ./generators/claude-code.nix;
  codexGenerator = import ./generators/codex.nix;

  mkGenerator =
    target:
    if target == "claude" then
      claudeCodeGenerator
    else if target == "codex" then
      codexGenerator
    else
      opencodeGenerator;
in
{
  mkAgentSystem =
    {
      pkgs,
      modules ? [ ],
      target ? "opencode",
    }:
    let
      evaluated = evalModules { inherit modules; };
      inherit (evaluated) config;
      generated = mkGenerator target { inherit lib config; };

      writeAgent = name: content: ''
        cp ${builtins.toFile "agent-${name}.md" content} "$out/agents/${name}.md"
      '';

      writeSkill = name: content: ''
        mkdir -p "$out/skills/${name}"
        cp ${builtins.toFile "skill-${name}.md" content} "$out/skills/${name}/SKILL.md"
      '';

      commonOutputs = ''
        mkdir -p "$out/agents" "$out/skills"
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList writeAgent generated.agents)}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList writeSkill generated.skills)}
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
      '';

      outputScript =
        if target == "claude" then
          claudeOutputs
        else if target == "codex" then
          codexOutputs
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
