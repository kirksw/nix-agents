# Structural correctness eval suite for nix-agents.
# Each derivation asserts a property of the generated configs.
# Integrated into `nix flake check` and run via `nix run .#bench`.
{
  pkgs,
  opencodeConfig,
  claudeConfig,
  codexConfig,
  ampConfig,
  tieredPiConfig ? null,
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

  # All skills must have YAML frontmatter with name and description (Pi requirement)
  eval-skill-frontmatter = pkgs.runCommand "eval-skill-frontmatter" { } ''
    ok=1
    for skill_dir in ${opencodeConfig}/skills/*/; do
      md="$skill_dir/SKILL.md"
      if [ -f "$md" ]; then
        # Check for --- fence, name: and description: in frontmatter
        if ! head -5 "$md" | grep -q '^---'; then
          echo "FAIL: Missing frontmatter fence in $md" >&2
          ok=0
        elif ! grep -q '^name: ' "$md"; then
          echo "FAIL: Missing name field in $md frontmatter" >&2
          ok=0
        elif ! grep -q '^description: ' "$md"; then
          echo "FAIL: Missing description field in $md frontmatter" >&2
          ok=0
        fi
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

  # Generated Markdown agents must include a name field for Pi subagent discovery
  eval-agent-frontmatter-name = pkgs.runCommand "eval-agent-frontmatter-name" { } ''
    ok=1
    for agent in ${opencodeConfig}/agents/*.md; do
      if ! grep -q '^name: ' "$agent"; then
        echo "FAIL: Missing name field in agent frontmatter: $agent" >&2
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
  eval-claude-settings =
    pkgs.runCommand "eval-claude-settings" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        jq -e '.permissions.allow | type == "array"' ${claudeConfig}/settings.json > /dev/null \
          || { echo "FAIL: settings.json missing permissions.allow array" >&2; exit 1; }
        touch $out
      '';

  # Claude MCP config must emit local servers using the current stdio schema
  eval-claude-mcp-json =
    pkgs.runCommand "eval-claude-mcp-json" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        jq -e '
          .mcpServers | type == "object" and
          (
            to_entries
            | all(
                if (.value | has("command")) then
                  .value.type == "stdio"
                else
                  true
                end
              )
          )
        ' ${claudeConfig}/.mcp.json > /dev/null \
          || { echo "FAIL: Claude MCP config local servers must declare type=stdio" >&2; exit 1; }
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

  # Tier 0/1 agents must not have disallowed tools in generated output
  eval-tier-tool-restriction = pkgs.runCommand "eval-tier-tool-restriction" { } (
    if tieredPiConfig == null then
      ''echo "SKIP: tieredPiConfig not provided"; touch $out''
    else
      ''
        ok=1
        for agent in orchestrator eng-manager qa-manager prod-manager architect-manager; do
          f="${tieredPiConfig}/agents/$agent.md"
          if [ -f "$f" ]; then
            tools_line=$(grep '^tools:' "$f" || echo "")
            if echo "$tools_line" | grep -qE 'write|edit|bash'; then
              echo "FAIL: $agent has disallowed tools: $tools_line" >&2
              ok=0
            fi
          else
            echo "FAIL: $agent agent file missing from tiered config: $f" >&2
            ok=0
          fi
        done
        # COO exception: may have read, but not write/edit/bash
        f="${tieredPiConfig}/agents/coo.md"
        if [ -f "$f" ]; then
          tools_line=$(grep '^tools:' "$f" || echo "")
          if echo "$tools_line" | grep -qE 'write|edit|bash'; then
            echo "FAIL: coo has disallowed tools: $tools_line" >&2
            ok=0
          fi
          if ! echo "$tools_line" | grep -q 'read'; then
            echo "FAIL: coo missing required read tool: $tools_line" >&2
            ok=0
          fi
        else
          echo "FAIL: coo agent file missing from tiered config: $f" >&2
          ok=0
        fi
        [ "$ok" = "1" ] || exit 1
        touch $out
      ''
  );

  # All managedAgents must be reflected as visibleAgents frontmatter for tiered agents
  eval-visible-agents = pkgs.runCommand "eval-visible-agents" { } (
    if tieredPiConfig == null then
      ''echo "SKIP: tieredPiConfig not provided"; touch $out''
    else
      ''
        ok=1
        for agent in orchestrator eng-manager qa-manager prod-manager architect-manager coo; do
          f="${tieredPiConfig}/agents/$agent.md"
          if [ -f "$f" ]; then
            if ! grep -q '^visibleAgents:' "$f"; then
              echo "FAIL: $agent missing visibleAgents frontmatter" >&2
              ok=0
            fi
          fi
        done
        [ "$ok" = "1" ] || exit 1
        touch $out
      ''
  );

  # managedAgents subset validation passes (proven by successful build of tieredPiConfig)
  eval-managed-subset = pkgs.runCommand "eval-managed-subset" { } (
    if tieredPiConfig == null then
      ''echo "SKIP: tieredPiConfig not provided"; touch $out''
    else
      ''
        # This is validated at Nix eval time by system.nix checkManagedSubset.
        # If tieredPiConfig built successfully, validation passed.
        test -d ${tieredPiConfig}/agents
        touch $out
      ''
  );

  # All tiered agents are present and the tiered config built (proves depth config eval passed)
  eval-tier-depth-config = pkgs.runCommand "eval-tier-depth-config" { } (
    if tieredPiConfig == null then
      ''echo "SKIP: tieredPiConfig not provided"; touch $out''
    else
      ''
        # Verify all tiered agents were generated (proves eval-time validation passed)
        for agent in orchestrator eng-manager qa-manager prod-manager architect-manager coo; do
          f="${tieredPiConfig}/agents/$agent.md"
          if [ ! -f "$f" ]; then
            echo "FAIL: $agent missing from tiered config" >&2
            exit 1
          fi
        done
        touch $out
      ''
  );

  # Skill content must not contain personal host references from old nixfiles content
  eval-no-stale-refs = pkgs.runCommand "eval-no-stale-refs" { } ''
    if grep -rq 'nixos-ry6a\|nixfiles-v2\| lunar ' ${opencodeConfig}/skills/ 2>/dev/null; then
      echo "FAIL: stale personal host/repo references found in skill content" >&2
      grep -r 'nixos-ry6a\|nixfiles-v2\| lunar ' ${opencodeConfig}/skills/ >&2
      exit 1
    fi
    touch $out
  '';

  # --------------------------------------------------------------------------
  # ADR-0001 base/profile model evals
  # --------------------------------------------------------------------------

  # Flat profile names resolve to default base when no base field is set.
  # This is the backward-compatibility path — existing configs must continue
  # to work without any bases defined.
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
              providers.test-cred = {
                credentialSource = "env";
                credentialRef = "TEST_KEY";
                envVar = "TEST_KEY";
              };
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
      # Flat names with base field resolve correctly
      [ "${r1.base}" = "alpha" ] || { echo "FAIL: expected base=alpha got ${r1.base}" >&2; exit 1; }
      [ "${r1.profile}" = "alpha" ] || { echo "FAIL: expected profile=alpha got ${r1.profile}" >&2; exit 1; }
      [ "${r2.base}" = "beta" ] || { echo "FAIL: expected base=beta got ${r2.base}" >&2; exit 1; }
      [ "${r2.profile}" = "beta" ] || { echo "FAIL: expected profile=beta got ${r2.profile}" >&2; exit 1; }
      # Explicit base/profile format
      [ "${r3.base}" = "work" ] || { echo "FAIL: expected base=work got ${r3.base}" >&2; exit 1; }
      [ "${r3.profile}" = "stable" ] || { echo "FAIL: expected profile=stable got ${r3.profile}" >&2; exit 1; }
      touch $out
    '';

  # Bases with providers scope provider access — profiles within a base
  # inherit base providers, and mkProfileMeta merges them correctly.
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
          profiles = {
            work-stable = {
              base = "work";
              providers = [ ];
              agents = [ ];
              skills = [ ];
              mcpServers = [ ];
            };
            personal-stable = {
              base = "personal";
              providers = [ ];
              agents = [ ];
              skills = [ ];
              mcpServers = [ ];
            };
          };
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

      # Extract base and provider count for each profile
      wsBase = meta.work-stable.base;
      psBase = meta.personal-stable.base;
      wsProvCount = builtins.toString (builtins.length meta.work-stable.providers);
      psProvCount = builtins.toString (builtins.length meta.personal-stable.providers);
    in
    pkgs.runCommand "eval-base-provider-isolation" { } ''
      # Work profile has work base
      [ "${wsBase}" = "work" ] || { echo "FAIL: work-stable base=${wsBase}" >&2; exit 1; }
      # Personal profile has personal base
      [ "${psBase}" = "personal" ] || { echo "FAIL: personal-stable base=${psBase}" >&2; exit 1; }
      # Each profile inherits exactly 1 provider from its base
      [ "${wsProvCount}" = "1" ] || { echo "FAIL: work-stable providers=${wsProvCount}" >&2; exit 1; }
      [ "${psProvCount}" = "1" ] || { echo "FAIL: personal-stable providers=${psProvCount}" >&2; exit 1; }
      touch $out
    '';

  # Two bases must not share the same stateDir. Validation must reject this.
  eval-base-state-dir-uniqueness =
    let
      lib' = pkgs.lib;
      types = import ../lib/core/types.nix { lib = lib'; };
      evalModules = import ../lib/core/eval.nix {
        lib = lib';
        inherit types;
      };

      # This should throw because two bases share the same stateDir
      evaluated = evalModules {
        modules = [
          {
            bases = {
              a.stateDir = "/shared/state";
              b.stateDir = "/shared/state";
            };
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

  # Profile referencing a nonexistent base must fail at eval time.
  eval-base-nonexistent-reject =
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
            profiles.test = {
              base = "nonexistent";
            };
          }
        ];
      };
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

  # Profile without a base field must fail at eval time.
  eval-base-required-reject =
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
              profiles.rogue = {
                pathPrefixes = [ "~/rogue/" ];
              };
            }
          ];
        }).config;
      result = builtins.tryEval (builders.resolveBaseProfile cfg "rogue");
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
}
