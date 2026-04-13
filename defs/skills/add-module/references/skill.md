# Skill Wizard

Ask for:

1. `name`: kebab-case such as `docker-workflow`
2. `description`: the trigger description, including both what the skill does and when it should trigger
3. skill structure: inline `content` for a small skill or `src = ./.;` for a directory-backed skill with `SKILL.md` and references
4. `version`: optional semver such as `1.0.0`

Guidance:

- Keep core workflow in `SKILL.md` or `content`
- Move large reference material into `references/`
- Use `scripts/` only when deterministic helpers are genuinely useful

Example inline shape:

```nix
# defs/skills/<name>.nix
{
  skills.<name> = {
    description = "<description>";
    content = ''
      # My Skill
    '';
    version = "1.0.0";
    resources = { };
    src = null;
  };
}
```

Example directory-backed shape:

```nix
# defs/skills/<name>/default.nix
{
  skills.<name> = {
    description = "<description>";
    src = ./.;
    version = "1.0.0";
  };
}
```
