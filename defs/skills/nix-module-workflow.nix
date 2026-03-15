{
  skills.nix-module-workflow = {
    description = "Add or modify agents, skills, MCP servers, hooks, and presets in nix-agents. Use when implementing new definitions, wiring them into the build, or understanding the module system layout.";
    content = ''
      # Nix-Agents Module Workflow

      ## Repository Layout

      | Directory          | What goes here                           |
      |--------------------|------------------------------------------|
      | `defs/agents/`     | Agent definitions (`agents.<name> = …`)  |
      | `defs/skills/`     | Skill definitions (`skills.<name> = …`)  |
      | `defs/mcps/`       | MCP server defs (`mcpServers.<name> = …`)|
      | `defs/hooks/`      | Hook definitions (take `{ pkgs }:`)      |
      | `presets/`         | Curated import bundles                   |
      | `modules/`         | Option declarations (NixOS module style) |
      | `lib/generators/`  | Per-tool config generators               |
      | `lib/schemas/`     | JSON schemas for generated outputs       |

      ## Skill Type Shape

      ```nix
      # defs/skills/my-skill.nix
      {
        skills.my-skill = {
          description = "One line — used as trigger description and shown in skill listings.";
          content = ''
            # My Skill

            Markdown body loaded when the skill triggers.
          '';
          resources = { };   # attrset of name -> path for bundled files
          src = null;        # set to a path to use a pre-built SKILL.md directory
        };
      }
      ```

      ## Agent Type Shape (key fields)

      ```nix
      # defs/agents/my-agent.nix
      {
        agents.my-agent = {
          description = "…";
          model = "balanced";       # fast | balanced | powerful | reasoning | literal string
          mode = "subagent";        # subagent | primary
          temperature = 0.2;
          prompt = ''…'';
          delegatesTo = [ "other-agent" ];
          skills = [ "skill-name" ];
          mcpServers = [ "server-name" ];
          permissions = {
            edit = "allow";         # allow | deny | { default = …; rules = { "*.md" = "allow"; }; }
            bash = "deny";
            task = { default = "deny"; rules = { "other-agent" = "allow"; }; };
            webfetch = "allow";
          };
        };
      }
      ```

      ## MCP Server Type Shape

      ```nix
      # defs/mcps/my-server.nix
      {
        mcpServers.my-server = {
          type = "local";          # local | remote
          command = [ "my-bin" "mcp" ];
          package = null;          # set to a Nix package derivation if command needs it
          url = null;              # for remote type
          environment = { };       # env vars passed to the server process
        };
      }
      ```

      ## Adding a New Definition

      1. Create `defs/<type>/<name>.nix` following the pattern above.
      2. Import it in the relevant preset in `presets/` (e.g. `presets/default.nix`).
      3. If an agent references the new skill/mcpServer, add it to the agent's `skills`/`mcpServers` list.
      4. Run `nix flake check` — `modules/system.nix` validates all cross-references at eval time.

      ## Validation Checks (auto-run by `nix flake check`)

      - `delegatesTo` targets must exist in `config.agents`
      - `skills` list must reference defined skill names
      - `mcpServers` list must reference defined MCP server names
      - `task.rules` keys must be agent names
      - Profile `agents`/`skills`/`mcpServers` lists must reference existing definitions

      ## Preset Pattern

      ```nix
      # presets/my-preset.nix
      { ... }:
      {
        imports = [
          ../defs/agents/my-agent.nix
          ../defs/skills/my-skill.nix
          ../defs/mcps/my-server.nix
        ];
      }
      ```

      ## Profile Pattern

      Profiles activate per-directory, filtering agents/skills and overriding tier/permissions:

      ```nix
      # presets/profiles.nix
      { ... }:
      {
        profiles.work = {
          pathPrefixes = [ "~/work/" ];
          agents = [ "code-monkey" "explore" ];  # empty = all
          skills = [ "swe-pruner-mcp" ];          # empty = all
          mcpServers = [ "swe-pruner" ];
          tierMapping = { powerful = "anthropic/claude-sonnet-4-6"; };
          permissions = { webfetch = "deny"; edit = null; bash = null; task = null; };
        };
      }
      ```
    '';
    version = "1.0.0";
    resources = { };
    src = null;
  };
}
