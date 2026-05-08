# Structural correctness eval suite for the reusable nix-agents engine.
{
  pkgs,
  opencodeConfig,
  claudeConfig,
  codexConfig,
  ampConfig,
  piConfig,
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
    test -f ${piConfig}/agents/my-agent.md
    test -f ${piConfig}/AGENTS.md
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
