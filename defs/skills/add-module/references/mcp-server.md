# MCP Server Wizard

Ask for:

1. `name`: kebab-case such as `my-db-tool`
2. `type`: `local` or `remote`
3. local details: `command` and optional `environment`
4. remote details: `url`, optional `transport`, optional `headers`

Guidance:

- Use `local` for subprocess servers on the same machine
- Use `remote` for HTTP or SSE endpoints
- If the server binary comes from a Nix package, that package is usually wired where `pkgs` is available rather than inside the bare def file

Emit this shape:

```nix
# defs/mcps/<name>.nix
{
  mcpServers.<name> = {
    type = "<type>";
    command = [ <command> ];
    environment = { };
  };
}
```
