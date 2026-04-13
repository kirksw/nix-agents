# Profile Wizard

Profiles live in `presets/profiles.nix` under the `profiles` attrset.

Ask for:

1. `name`
2. `pathPrefixes`
3. `agents`
4. `skills`
5. `mcpServers`
6. optional `tierMapping`
7. optional `permissions`

Explain that empty lists mean "all" for `agents`, `skills`, and `mcpServers`.

Emit this block:

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

No additional import is needed because `presets/profiles.nix` is already part of the default module set.
