# Structural correctness eval suite for the reusable nix-agents engine.
{
  pkgs,
  opencodeConfig,
  claudeConfig,
  codexConfig,
  ampConfig,
  piConfig,
  opencodeWrapper,
  claudeWrapper,
  codexWrapper,
  piWrapper,
}:
{
  eval-skill-content = pkgs.runCommand "eval-skill-content" { } ''
    md="${opencodeConfig}/skills/project-context/SKILL.md"
    test -s "$md" || { echo "FAIL: missing example skill" >&2; exit 1; }
    grep -q '^name: "project-context"' "$md"
    grep -q '^description: ' "$md"
    touch $out
  '';

  eval-agent-files = pkgs.runCommand "eval-agent-files" { } ''
    f="${opencodeConfig}/agents/my-agent.md"
    test -f "$f" || { echo "FAIL: missing example agent" >&2; exit 1; }
    grep -q '^name: my-agent' "$f"
    touch $out
  '';

  eval-opencode-json = pkgs.runCommand "eval-opencode-json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq -e '.mcp | type == "object"' ${opencodeConfig}/opencode.json > /dev/null
    touch $out
  '';

  eval-claude-settings =
    pkgs.runCommand "eval-claude-settings" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        jq -e '.permissions.allow | type == "array"' ${claudeConfig}/settings.json > /dev/null
        jq -e '.permissions.allow | index("Edit") and index("Bash(git *)")' ${claudeConfig}/settings.json > /dev/null
        jq -e '.permissions.deny | index("Bash") and index("Task")' ${claudeConfig}/settings.json > /dev/null
        jq -e '.permissions.ask | index("WebFetch")' ${claudeConfig}/settings.json > /dev/null
        jq -e '[.permissions.allow[], .permissions.deny[], .permissions.ask[]] | all(test("^[A-Za-z]+:") | not)' ${claudeConfig}/settings.json > /dev/null
        touch $out
      '';

  eval-claude-mcp-json =
    pkgs.runCommand "eval-claude-mcp-json" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        jq -e '.mcpServers | type == "object"' ${claudeConfig}/.mcp.json > /dev/null
        touch $out
      '';

  eval-hook-manifest = pkgs.runCommand "eval-hook-manifest" { } ''
    manifest="${opencodeConfig}/hook-manifest"
    if [ -s "$manifest" ]; then
      grep -qE '^[a-z-]+:/' "$manifest" || { echo "FAIL: hook-manifest has invalid format" >&2; exit 1; }
    fi
    touch $out
  '';

  eval-codex-mcp-toml =
    pkgs.runCommand "eval-codex-mcp-toml" { nativeBuildInputs = [ pkgs.python3 ]; }
      ''
        python -c 'import pathlib, tomllib; data = tomllib.loads(pathlib.Path("${codexConfig}/mcp.nix.toml").read_text()); assert isinstance(data.get("mcp_servers", {}), dict)'
        touch $out
      '';

  eval-amp-json = pkgs.runCommand "eval-amp-json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq -e '.systemPrompt | type == "string"' ${ampConfig}/amp.json > /dev/null
    jq -e '.mcpServers | type == "array"' ${ampConfig}/amp.json > /dev/null
    touch $out
  '';

  eval-pi-config = pkgs.runCommand "eval-pi-config" { } ''
    agent="${piConfig}/agents/my-agent.md"
    test -f "$agent"
    test -f ${piConfig}/AGENTS.md
    grep -q '^model: anthropic/claude-sonnet-4-5$' "$agent"
    grep -q '^fallbackModels: \["anthropic/claude-haiku-4-5-20251001"\]$' "$agent"
    touch $out
  '';

  eval-tier-manifest = pkgs.runCommand "eval-tier-manifest" { } ''
    manifest="${piConfig}/AGENTS.md"
    grep -q '<!-- nix-agents:tier-manifest:start -->' "$manifest" || {
      echo "FAIL: tier-manifest start marker missing" >&2
      exit 1
    }
    grep -q '<!-- nix-agents:tier-manifest:end -->' "$manifest" || {
      echo "FAIL: tier-manifest end marker missing" >&2
      exit 1
    }
    grep -Eq '^\| S \| anthropic/claude-sonnet-4-5 \| anthropic/claude-haiku-4-5-20251001 \|$' "$manifest" || {
      echo "FAIL: tier -> model-chain table row missing" >&2
      exit 1
    }
    touch $out
  '';

  wrapper-sync-mode = pkgs.runCommand "wrapper-sync-mode" { } ''
    codexWrapperPath=${codexWrapper}/bin/codex
    piWrapperPath=${piWrapper}/bin/pi

    for wrapper in "$codexWrapperPath" "$piWrapperPath"; do
      test -f "$wrapper" || { echo "FAIL: missing wrapper at $wrapper" >&2; exit 1; }
      grep -Fq '_NAX_SYNC_MODE=' "$wrapper" || {
        echo "FAIL: sync mode env missing in $wrapper" >&2
        exit 1
      }
      grep -Fq '_nax_should_sync_path()' "$wrapper" || {
        echo "FAIL: _nax_should_sync_path missing in $wrapper" >&2
        exit 1
      }
      grep -Fq 'always) return 0' "$wrapper" || {
        echo "FAIL: syncMode always branch missing in $wrapper" >&2
        exit 1
      }
      grep -Fq 'never) return 1' "$wrapper" || {
        echo "FAIL: syncMode never branch missing in $wrapper" >&2
        exit 1
      }
      grep -Fq 'bootstrap) [ ! -e "$target_path" ]' "$wrapper" || {
        echo "FAIL: syncMode bootstrap branch missing in $wrapper" >&2
        exit 1
      }

      common_line=$(grep -n "_sync_common_profile_assets \"\$_NAX_TOOL_CONFIG_DIR\"" "$wrapper" | head -n1 | cut -d: -f1)
      hook_line=$(grep -n "_run_hook session-start" "$wrapper" | head -n1 | cut -d: -f1)
      [ -n "$common_line" ] || {
        echo "FAIL: _sync_common_profile_assets not found in $wrapper" >&2
        exit 1
      }
      [ -n "$hook_line" ] || {
        echo "FAIL: _run_hook session-start not found in $wrapper" >&2
        exit 1
      }
      [ "$common_line" -lt "$hook_line" ] || {
        echo "FAIL: common asset sync must occur before session-start in $wrapper" >&2
        exit 1
      }
    done

    grep -Fq '_sync_link_dir_force "$_pi_state_dir/sessions" "$_pi_profile_dir/sessions"' "$piWrapperPath" || {
      echo "FAIL: Pi sessions sync must be unconditional" >&2
      exit 1
    }
    if grep -Fq '_sync_link_dir "$_pi_state_dir/sessions" "$_pi_profile_dir/sessions"' "$piWrapperPath"; then
      echo "FAIL: Pi sessions sync must not go through gated _sync_link_dir" >&2
      exit 1
    fi

    touch $out
  '';

  eval-base-profile-resolution =
    let
      lib' = pkgs.lib;
      types = import ../lib/core/types.nix { lib = lib'; };
      evalModules = import ../lib/core/eval.nix {
        lib = lib';
        inherit types;
      };
      builders = import ../lib/core/builders.nix {
        lib = lib';
        inherit evalModules;
      };

      cfg =
        (evalModules {
          modules = [
            {
              bases.alpha.pathPrefixes = [ "~/alpha/" ];
              bases.beta.pathPrefixes = [ "~/beta/" ];
              profiles.alpha = {
                base = "alpha";
                pathPrefixes = [ "~/alpha/" ];
              };
              profiles.beta = {
                base = "beta";
                pathPrefixes = [ "~/beta/" ];
              };
            }
          ];
        }).config;
      rbp = builders.resolveBaseProfile cfg;
      r1 = rbp "alpha";
      r2 = rbp "beta";
      r3 = rbp "work/stable";
    in
    pkgs.runCommand "eval-base-profile-resolution" { } ''
      [ "${r1.base}" = "alpha" ] || exit 1
      [ "${r1.profile}" = "alpha" ] || exit 1
      [ "${r2.base}" = "beta" ] || exit 1
      [ "${r2.profile}" = "beta" ] || exit 1
      [ "${r3.base}" = "work" ] || exit 1
      [ "${r3.profile}" = "stable" ] || exit 1
      touch $out
    '';

  eval-base-provider-isolation =
    let
      lib' = pkgs.lib;
      types = import ../lib/core/types.nix { lib = lib'; };
      evalModules = import ../lib/core/eval.nix {
        lib = lib';
        inherit types;
      };
      builders = import ../lib/core/builders.nix {
        lib = lib';
        inherit evalModules;
      };

      testModules = [
        {
          providers.work-key = {
            credentialSource = "env";
            credentialRef = "WORK_KEY";
            envVar = "WORK_KEY";
          };
          providers.personal-key = {
            credentialSource = "env";
            credentialRef = "PERSONAL_KEY";
            envVar = "PERSONAL_KEY";
          };
          bases.work.providers = [ "work-key" ];
          bases.personal.providers = [ "personal-key" ];
          profiles.work-stable.base = "work";
          profiles.personal-stable.base = "personal";
          agents.test-agent = {
            description = "test";
            model = "fast";
            prompt = "test";
          };
        }
      ];

      meta = builders.mkProfileMeta {
        inherit pkgs;
        modules = testModules;
        target = "opencode";
      };
    in
    pkgs.runCommand "eval-base-provider-isolation" { } ''
      [ "${meta.work-stable.base}" = "work" ] || exit 1
      [ "${meta.personal-stable.base}" = "personal" ] || exit 1
      [ "${builtins.toString (builtins.length meta.work-stable.providers)}" = "1" ] || exit 1
      [ "${builtins.toString (builtins.length meta.personal-stable.providers)}" = "1" ] || exit 1
      touch $out
    '';

  eval-base-state-dir-uniqueness =
    let
      lib' = pkgs.lib;
      types = import ../lib/core/types.nix { lib = lib'; };
      evalModules = import ../lib/core/eval.nix {
        lib = lib';
        inherit types;
      };
      evaluated = evalModules {
        modules = [
          {
            bases.a.stateDir = "/shared/state";
            bases.b.stateDir = "/shared/state";
          }
        ];
      };
      result = builtins.tryEval evaluated.config._validated;
    in
    pkgs.runCommand "eval-base-state-dir-uniqueness" { } ''
      ${
        if result.success then
          "echo 'FAIL: duplicate stateDir should have been rejected' >&2; exit 1"
        else
          "# Correctly rejected"
      }
      touch $out
    '';

  eval-base-nonexistent-reject =
    let
      lib' = pkgs.lib;
      types = import ../lib/core/types.nix { lib = lib'; };
      evalModules = import ../lib/core/eval.nix {
        lib = lib';
        inherit types;
      };
      evaluated = evalModules { modules = [ { profiles.test.base = "nonexistent"; } ]; };
      result = builtins.tryEval evaluated.config._validated;
    in
    pkgs.runCommand "eval-base-nonexistent-reject" { } ''
      ${
        if result.success then
          "echo 'FAIL: nonexistent base should have been rejected' >&2; exit 1"
        else
          "# Correctly rejected"
      }
      touch $out
    '';

  eval-base-required-reject =
    let
      lib' = pkgs.lib;
      types = import ../lib/core/types.nix { lib = lib'; };
      evalModules = import ../lib/core/eval.nix {
        lib = lib';
        inherit types;
      };
      evaluated = evalModules { modules = [ { profiles.rogue.pathPrefixes = [ "~/rogue/" ]; } ]; };
      result = builtins.tryEval evaluated.config._validated;
    in
    pkgs.runCommand "eval-base-required-reject" { } ''
      ${
        if result.success then
          "echo 'FAIL: profile without base should have been rejected' >&2; exit 1"
        else
          "# Correctly rejected"
      }
      touch $out
    '';

  eval-profile-sandbox-meta =
    let
      lib' = pkgs.lib;
      types = import ../lib/core/types.nix { lib = lib'; };
      evalModules = import ../lib/core/eval.nix {
        lib = lib';
        inherit types;
      };
      builders = import ../lib/core/builders.nix {
        lib = lib';
        inherit evalModules;
      };
      meta = builders.mkProfileMeta {
        inherit pkgs;
        target = "codex";
        modules = [
          {
            sandboxes.default = {
              from = "openclaw";
              providers = [ "github" ];
              uploadProject = false;
            };
            bases.test = { };
            profiles.test = {
              base = "test";
              sandbox = "default";
            };
            agents.test-agent = {
              description = "test";
              model = "fast";
              prompt = "test";
            };
          }
        ];
      };
      uploadProject = if meta.test.sandbox.uploadProject then "true" else "false";
    in
    pkgs.runCommand "eval-profile-sandbox-meta" { } ''
      [ "${meta.test.sandbox.from}" = "openclaw" ] || exit 1
      [ "${uploadProject}" = "false" ] || exit 1
      touch $out
    '';

  eval-profile-sandbox-reject =
    let
      lib' = pkgs.lib;
      types = import ../lib/core/types.nix { lib = lib'; };
      evalModules = import ../lib/core/eval.nix {
        lib = lib';
        inherit types;
      };
      evaluated = evalModules {
        modules = [
          {
            bases.test = { };
            profiles.test = {
              base = "test";
              sandbox = "missing";
            };
          }
        ];
      };
      result = builtins.tryEval evaluated.config._validated;
    in
    pkgs.runCommand "eval-profile-sandbox-reject" { } ''
      ${
        if result.success then
          "echo 'FAIL: nonexistent sandbox should have been rejected' >&2; exit 1"
        else
          "# Correctly rejected"
      }
      touch $out
    '';
}
