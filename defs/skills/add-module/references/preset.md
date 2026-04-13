# Preset Wizard

Ask for:

1. `name`: descriptive filename such as `data-team`
2. `imports`: which agents, skills, MCP servers, or other presets to include
3. optional inline config: `tierMapping`, `defaultPermissions`, `human`, or `providers`

Emit this shape:

```nix
# presets/<name>.nix
{ ... }:
{
  imports = [
    <imports>
  ];
}
```

Prefer presets for reusable bundles rather than one-off project-specific tweaks.
