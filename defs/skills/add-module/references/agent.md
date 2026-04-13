# Agent Wizard

Ask for these fields in order and explain each one before asking.

1. `name`: kebab-case identifier such as `data-analyst`
2. `description`: one sentence shown in tool UIs
3. `model`: `fast`, `balanced`, `powerful`, `reasoning`, or a literal model string
4. `prompt`: the role, escalation behavior, and output style
5. `permissions`: `edit`, `bash`, `task`, `webfetch`
6. `delegatesTo`: existing agent names this agent may call
7. `skills`: optional skill names
8. `mcpServers`: optional MCP server names

Permission guidance:

- `edit`: allow for implementors, deny for reviewers, or scope with rules
- `bash`: allow for implementors, scope or deny for read-only agents
- `task`: if delegation is allowed, collect the specific agent names
- `webfetch`: usually allow or deny directly

Emit this shape:

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

Use a multiline indented string for longer prompts.
