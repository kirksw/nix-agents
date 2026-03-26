# Structural correctness eval suite for nix-agents.
# Each derivation asserts a property of the generated configs.
# Integrated into `nix flake check` and run via `nix run .#bench`.
{
  pkgs,
  opencodeConfig,
  claudeConfig,
  codexConfig,
  ampConfig,
}:
{
  # All skills must have a non-empty SKILL.md
  eval-skill-content = pkgs.runCommand "eval-skill-content" { } ''
    ok=1
    for skill_dir in ${opencodeConfig}/skills/*/; do
      md="$skill_dir/SKILL.md"
      if [ ! -f "$md" ]; then
        echo "FAIL: Missing SKILL.md: $skill_dir" >&2
        ok=0
      elif [ ! -s "$md" ]; then
        echo "FAIL: Empty SKILL.md: $skill_dir" >&2
        ok=0
      fi
    done
    [ "$ok" = "1" ] || exit 1
    touch $out
  '';

  # All expected agents must be present in generated output
  eval-agent-files = pkgs.runCommand "eval-agent-files" { } ''
    ok=1
    for agent in code-monkey explore the-architect 10xBEAST bottleneck chaos-demon code-red scribe; do
      f="${opencodeConfig}/agents/$agent.md"
      if [ ! -f "$f" ]; then
        echo "FAIL: Missing agent file: $f" >&2
        ok=0
      fi
    done
    [ "$ok" = "1" ] || exit 1
    touch $out
  '';

  # opencode.json must be valid JSON with an mcp key
  eval-opencode-json = pkgs.runCommand "eval-opencode-json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq -e '.mcp' ${opencodeConfig}/opencode.json > /dev/null \
      || { echo "FAIL: opencode.json missing mcp key" >&2; exit 1; }
    touch $out
  '';

  # settings.json must have permissions.allow as an array
  eval-claude-settings = pkgs.runCommand "eval-claude-settings" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq -e '.permissions.allow | type == "array"' ${claudeConfig}/settings.json > /dev/null \
      || { echo "FAIL: settings.json missing permissions.allow array" >&2; exit 1; }
    touch $out
  '';

  # hook-manifest must be empty or contain only valid event:path lines
  eval-hook-manifest = pkgs.runCommand "eval-hook-manifest" { } ''
    manifest="${opencodeConfig}/hook-manifest"
    if [ -s "$manifest" ]; then
      grep -qE '^[a-z-]+:/' "$manifest" \
        || { echo "FAIL: hook-manifest has invalid format" >&2; exit 1; }
    fi
    touch $out
  '';

  # codex mcp.json must exist and be valid JSON
  eval-codex-mcp-json = pkgs.runCommand "eval-codex-mcp-json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq -e '. | type == "array"' ${codexConfig}/mcp.json > /dev/null \
      || { echo "FAIL: codex mcp.json is not a JSON array" >&2; exit 1; }
    touch $out
  '';

  # amp.json must have systemPrompt and mcpServers keys
  eval-amp-json = pkgs.runCommand "eval-amp-json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq -e '.systemPrompt | type == "string"' ${ampConfig}/amp.json > /dev/null \
      || { echo "FAIL: amp.json missing systemPrompt" >&2; exit 1; }
    jq -e '.mcpServers | type == "array"' ${ampConfig}/amp.json > /dev/null \
      || { echo "FAIL: amp.json missing mcpServers" >&2; exit 1; }
    touch $out
  '';

  # Skill content must not contain personal host references from old nixfiles content
  eval-no-stale-refs = pkgs.runCommand "eval-no-stale-refs" { } ''
    if grep -rq 'nixos-ry6a\|nixfiles-v2\| lunar ' ${opencodeConfig}/skills/ 2>/dev/null; then
      echo "FAIL: stale personal host/repo references found in skill content" >&2
      grep -r 'nixos-ry6a\|nixfiles-v2\| lunar ' ${opencodeConfig}/skills/ >&2
      exit 1
    fi
    touch $out
  '';
}
