# Hook Wizard

Warn first: hooks take `{ pkgs }:` and are not added through preset imports. They must be wired manually in `flake.nix`.

Ask for:

1. `name`: descriptive filename such as `notify-on-error`
2. `event`: `session-start`, `session-end`, `delegation`, `skill-invoked`, `human-decision`, `commit`, or `error`
3. `command`: shell script body, with event JSON on stdin
4. `package`: optional tool dependency such as `pkgs.jq`

Emit this shape:

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

Use a multiline indented string for non-trivial shell bodies.
