# Wiring And Validation

## Wiring

For agents, skills, and MCP servers, add the new module path to the relevant preset import list, usually `presets/default.nix`:

```nix
imports = [
  ../defs/<type>/<name>.nix
];
```

Directory-backed skills can be imported by directory path instead:

```nix
imports = [
  ../defs/skills/<name>
];
```

If an agent references a new skill or MCP server, also update that agent's `skills` or `mcpServers` list.

Hooks are different. Wire them in `flake.nix`, not a preset:

```nix
modules = defaultModules ++ [ (import ./defs/hooks/<name>.nix { inherit pkgs; }) ];
```

Profiles are added directly inside `presets/profiles.nix`.

## Validation

After creating and wiring the module:

```bash
nix run .#fmt
nix run .#lint
nix build .#claude-config
nix build .#opencode-config
nix flake check
```

If a build fails with missing references such as undefined skills or delegate targets, check the names in the new module against existing definitions.

## Existing Names

- Agents: `code-monkey`, `explore`, `10xBEAST`, `the-architect`, `bottleneck`, `chaos-demon`, `code-red`, `scribe`
- Skills: `nix-agents`, `system-context`, `secrets-management`, `skill-creator`, `session-resume`, `swe-pruner-mcp`, `add-module`, `parallel-reviews`
- MCP servers: `agent-observe`, `swe-pruner`
- Hooks: `session-write`
- Presets: `default`, `minimal`, `security`, `profiles`
