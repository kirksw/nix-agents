# Nix Coding Style

Follow these conventions when writing Nix code in this repository.

## Formatting

- Use 2-space indentation
- Use `nixfmt-rfc-style` (not plain `nixfmt`) as documented by the repo
- Format all `.nix` files before committing: `nix run .#fmt`
- Check format without modifying: `nixfmt --check <file>`

## Linting

```bash
nix run .#lint
statix check .
deadnix --fail .
```

## Module Pattern For `defs/`

Agent, skill, and MCP defs are plain attrsets. Do not add `{ config, lib, ... }:` boilerplate unless the file actually needs special args.

```nix
# defs/agents/my-agent.nix
{
  agents.my-agent = {
    description = "…";
    model = "balanced";
    prompt = "Implement the task.";
  };
}
```

## Module Pattern For `modules/`

Module declarations use NixOS-style options.

```nix
# modules/my-module.nix
{ lib, types, ... }:
{
  options.myOption = lib.mkOption {
    type = types.str;
    default = "";
    description = "…";
  };
}
```

## Config Generation Pattern

Generators produce JSON or YAML strings via `builtins.toJSON`.

```nix
builtins.toJSON {
  agents = lib.mapAttrsToList (name: agent: { inherit name; ... }) config.agents;
}
```

## Naming

- Use kebab-case for agent, skill, and MCP names: `agents.my-agent`, `skills.nix-agents`
- Use camelCase for Nix option paths: `options.tierMapping`, `options.mcpServers`

## Common Patterns

Optional attributes:

```nix
{ required = "value"; }
// lib.optionalAttrs condition { optional = "value"; }
```

Filtering attrsets:

```nix
lib.filterAttrs (name: _: builtins.elem name whitelist) attrset
```

Mapping attrsets to lists:

```nix
lib.mapAttrsToList (name: value: { inherit name; ... }) attrset
```

## Testing

Run before committing:

```bash
nix run .#fmt
nix run .#lint
nix flake check
```
