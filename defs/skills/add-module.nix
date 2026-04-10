{
  skills.add-module = {
    description = "Interactively add any nix-agents module type — agent, skill, MCP server, hook, preset, or profile. Use when the user wants to create a new definition, understand what each module type does, or get step-by-step guidance wiring a new module into the build.";
    content = ''
      # Add Module — Interactive Wizard

      Guide the user through adding a new module to nix-agents. Ask one focused question at a
      time. Do not create any files until all required fields are confirmed.

      For field shapes and validation rules, refer to the `nix-module-workflow` skill.

      ---

      ## Step 1: Choose Module Type

      Ask which module type they want to add. Present as a numbered list — include the one-line
      purpose for each so they can choose without prior knowledge:

      1. **Agent** — An LLM persona with a defined role, model tier, system prompt, and
         permission set. Agents can delegate to other agents and have skills/MCP servers attached.
         *Example use: a security auditor, a documentation writer, a code reviewer.*

      2. **Skill** — A markdown prompt template loaded into Claude Code as a slash command.
         Skills carry specialised workflows or domain knowledge. They do not execute code —
         they guide Claude's behaviour.
         *Example use: a coding style guide, a deployment checklist, an API workflow.*

      3. **MCP Server** — A Model Context Protocol server that exposes external tools or data
         sources to agents. Can be a local subprocess or a remote HTTP/SSE endpoint.
         *Example use: a database query tool, a Jira integration, a file search service.*

      4. **Hook** — A shell script triggered on lifecycle events (session start/end, commit,
         delegation, errors). Hooks require `pkgs` and must be wired manually in `flake.nix`.
         *Example use: session logging, Slack notifications on errors.*

      5. **Preset** — A curated `imports` bundle grouping agents, skills, and MCPs together.
         Presets compose with each other.
         *Example use: a "security team" preset, a "minimal CI" preset.*

      6. **Profile** — A runtime context that activates based on the working directory path.
         Profiles filter which agents/skills/MCPs are active and can remap model tiers.
         *Example use: a "work" profile with restricted agents, a "home" profile with full access.*

      ---

      ## Step 2: Collect Fields

      ### Agent

      Ask in order. For each field explain its purpose before asking.

      1. **name** — kebab-case identifier (e.g. `data-analyst`). Becomes `agents.<name>`.
      2. **description** — one sentence shown in tool UIs. Make it precise: what does this
         agent DO and WHEN should you call it?
      3. **model** — capability tier. Explain each option then ask:
         - `fast` — cheap and quick (Haiku class); good for simple lookups
         - `balanced` — everyday tasks (Sonnet class); use this for most agents
         - `powerful` — complex multi-step work (Sonnet/Opus class)
         - `reasoning` — deep analysis, architecture, hard debugging (extended thinking)
         - Or a literal model string like `"anthropic/claude-sonnet-4-6"`
      4. **prompt** — the system prompt. Ask the user to describe the agent's primary role,
         what it should escalate, and expected output style. Then draft a concise imperative
         prompt and confirm before proceeding.
      5. **permissions** — explain each, suggest a default, then ask:
         - `edit`: write files? `"allow"` for implementors, `"deny"` for reviewers.
           Can be scoped: `{ default = "deny"; rules = { "*.nix" = "allow"; }; }`
         - `bash`: run shell commands? `"allow"` for implementors, scoped for read-only work.
         - `task`: dispatch sub-agents? If yes, ask which — generates
           `{ default = "deny"; rules = { "agent-name" = "allow"; }; }`
         - `webfetch`: fetch URLs? `"allow"` or `"deny"`.
      6. **delegatesTo** — list of agent names this agent can call via the Task tool. Must
         match existing names in `defs/agents/` (or being added now).
      7. **skills** (optional) — skill names to load into this agent's context.
      8. **mcpServers** (optional) — MCP server names to expose.

      Confirm all fields, then emit:

      ```nix
      # defs/agents/<name>.nix
      {
        agents.<name> = {
          description = "<description>";
          mode = "subagent";
          model = "<model>";
          temperature = 0.2;
          prompt = "<prompt>";
          delegatesTo = [ <delegatesTo> ];
          permissions = {
            edit = <edit>;
            bash = <bash>;
            task = <task>;
            webfetch = <webfetch>;
          };
          skills = [ <skills> ];
          mcpServers = [ <mcpServers> ];
        };
      }
      ```

      Note: for multi-paragraph prompts use a multiline Nix string — see existing agents in
      `defs/agents/` for reference.

      ---

      ### Skill

      1. **name** — kebab-case (e.g. `docker-workflow`). Becomes `skills.<name>`.
      2. **description** — this is the TRIGGER. Explain that it determines when Claude
         auto-loads the skill, so it must include both what the skill does AND the situations
         that should trigger it.
         *Bad: "Docker guide." Good: "Docker workflow guide. Use when building images, writing
         Dockerfiles, debugging container issues, or setting up compose stacks."*
      3. **content** — the markdown body. Ask what procedures, commands, or reference tables
         it should contain. Keep it under 500 lines; large reference material belongs in
         bundled `resources` files (mention this option but don't pursue it unless needed).
      4. **version** (optional) — semver string, e.g. `"1.0.0"`.

      Confirm, then emit:

      ```nix
      # defs/skills/<name>.nix
      {
        skills.<name> = {
          description = "<description>";
          content = "<content>";
          version = "1.0.0";
          resources = { };
          src = null;
        };
      }
      ```

      Note: for multi-line content use a Nix indented string — see existing skills in
      `defs/skills/` for reference.

      ---

      ### MCP Server

      1. **name** — kebab-case (e.g. `my-db-tool`). Becomes `mcpServers.<name>`.
      2. **type** — `"local"` (subprocess on the same machine) or `"remote"` (HTTP/SSE endpoint).
      3. If `local`:
         - **command** — executable + args as a list, e.g. `[ "my-mcp-server" "start" ]`.
           Note: if the binary comes from a Nix package, the `package` field must be set at
           the flake level where `pkgs` is available, not in the def file.
         - **environment** (optional) — env vars passed to the server process.
      4. If `remote`:
         - **url** — full HTTP/SSE endpoint URL.
         - **transport** (optional) — `"http"` or `"sse"`.
         - **headers** (optional) — auth headers as an attrset.

      Confirm, then emit:

      ```nix
      # defs/mcps/<name>.nix
      {
        mcpServers.<name> = {
          type = "<type>";
          command = [ <command> ]; # local
          # url = "<url>";         # remote
          environment = { };
        };
      }
      ```

      ---

      ### Hook

      **Warn upfront:** hooks take `{ pkgs }:` and CANNOT be added via `imports` in a preset.
      They must be wired manually in `flake.nix`:
      ```nix
      modules = defaultModules ++ [ (import ./defs/hooks/<name>.nix { inherit pkgs; }) ];
      ```

      1. **name** — descriptive filename (e.g. `notify-on-error`).
      2. **event** — one of: `session-start`, `session-end`, `delegation`, `skill-invoked`,
         `human-decision`, `commit`, `error`.
      3. **command** — shell script body. Receives event JSON on stdin. Ask what the user
         wants to do (log, notify, update a file, call an API, etc.).
      4. **package** (optional) — if the script needs a tool (e.g. `pkgs.jq`), note that
         the package reference uses `pkgs.<name>`.

      Confirm, then emit:

      ```nix
      # defs/hooks/<name>.nix
      { pkgs }:
      {
        hooks = [
          {
            event = "<event>";
            package = <pkgs.package or null>;
            command = "<command script>";
          }
        ];
      }
      ```

      Note: for multi-line command scripts use a Nix indented string — see `defs/hooks/` for
      reference.

      ---

      ### Preset

      1. **name** — descriptive filename (e.g. `data-team`).
      2. **imports** — ask which existing agents, skills, and MCP servers to include. List
         what exists in `defs/agents/`, `defs/skills/`, `defs/mcps/`. User may also include
         other presets (e.g. `./minimal.nix`).
      3. **inline config** (optional) — ask if they want to set `tierMapping`,
         `defaultPermissions`, `human`, or `providers` inline.

      Confirm, then emit:

      ```nix
      # presets/<name>.nix
      { ... }:
      {
        imports = [
          <imports>
        ];
      }
      ```

      ---

      ### Profile

      Profiles live in `presets/profiles.nix` inside the `profiles` attrset.

      1. **name** — profile identifier (e.g. `data-work`).
      2. **pathPrefixes** — directory prefixes that activate this profile, e.g.
         `[ "~/work/data/" "~/projects/analytics/" ]`.
      3. **agents** — whitelist of agent names; empty list = all agents active.
      4. **skills** — whitelist of skill names; empty = all.
      5. **mcpServers** — whitelist of MCP server names; empty = all.
      6. **tierMapping** (optional) — override model tiers for this profile, e.g.
         `{ reasoning = "anthropic/claude-opus-4-6"; }`.
      7. **permissions** (optional) — profile-level permission overrides, e.g.
         `{ webfetch = "deny"; }`.

      Confirm, then show the block to add inside `presets/profiles.nix`:

      ```nix
      profiles.<name> = {
        pathPrefixes = [ <pathPrefixes> ];
        agents = [ <agents> ];
        skills = [ <skills> ];
        mcpServers = [ <mcpServers> ];
        tierMapping = { <tierMapping> };
        permissions = { <permissions> };
      };
      ```

      ---

      ## Step 3: Wire Into the Build

      ### Agents, Skills, MCP Servers

      Ask which preset should include the new module (default: `presets/default.nix`).
      Show the line to add:

      ```nix
      # In presets/default.nix (or chosen preset):
      imports = [
        # … existing imports …
        ../defs/<type>/<name>.nix   # ADD THIS LINE
      ];
      ```

      If an agent references the new skill or MCP server, remind the user to add it to that
      agent's `skills` or `mcpServers` list as well.

      ### Hooks

      Remind: wire in `flake.nix`, not in a preset:

      ```nix
      modules = defaultModules ++ [ (import ./defs/hooks/<name>.nix { inherit pkgs; }) ];
      ```

      ### Profiles

      Add the block inside `presets/profiles.nix` in the `profiles` attrset. No additional
      import needed — `profiles.nix` is already in `defaultModules`.

      ---

      ## Step 4: Validate

      After all files are created and wired:

      ```bash
      # 1. Format all .nix files (required before committing)
      nix run .#fmt

      # 2. Lint for anti-patterns and dead code
      nix run .#lint

      # 3. Build configs — triggers cross-reference validation in modules/system.nix
      nix build .#claude-config
      nix build .#opencode-config

      # 4. Full check suite (format + lint + schema-compat + config-gen + wrapper smoke tests)
      nix flake check
      ```

      If `nix build` fails with "Referenced skills not defined" or "delegatesTo targets do not
      exist", cross-check the names in the def files against existing definitions.

      ---

      ## Step 5: Sync (Optional)

      To immediately use the new config in local tools:

      ```bash
      nix run .#sync
      ```

      For Claude Code specifically, the sync writes to `~/.config/nix-agents/claude/`.

      ---

      ## Existing Module Names (Reference)

      - **Agents:** code-monkey, explore, 10xBEAST, the-architect, bottleneck, chaos-demon,
        code-red, scribe
      - **Skills:** nix-coding-style, nix-flake-ops, nix-module-workflow, secrets-management,
        skill-creator, session-resume, swe-pruner-mcp, add-module
      - **MCP servers:** agent-observe, swe-pruner
      - **Hooks:** session-write
      - **Presets:** default, minimal, security, profiles
    '';
    version = "1.0.0";
    resources = { };
    src = null;
  };
}
