# Skill Creation Process

## 1. Understand The Skill

Start with concrete examples of how the skill will be used. Ask a few focused questions rather than a large batch.

Good prompts to elicit usage:

- What should this skill help with?
- What would a user say that should trigger it?
- What are two or three realistic tasks this skill should handle?

Conclude this step when the trigger conditions and core workflows are clear.

## 2. Plan Reusable Resources

For each example, ask:

1. What would the model have to rediscover every time?
2. What should become a script, reference doc, or asset?

Examples:

- PDF rotation repeated each time: add `scripts/rotate_pdf.py`
- Schema rediscovery each time: add `references/schema.md`
- Reused frontend boilerplate: add `assets/template/`

## 3. Initialize The Skill

When creating a new skill from scratch, run:

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

This creates:

- a `SKILL.md` template with frontmatter
- example `scripts/`, `references/`, and `assets/` directories
- example files you can customize or delete

Skip this step only when iterating on an existing skill.

## 4. Edit The Skill

When editing the skill:

- start with reusable resources first
- delete unused example files from initialization
- test any added scripts by actually running them
- write `SKILL.md` in imperative form

For `SKILL.md`:

- keep trigger guidance in the frontmatter description
- keep the body focused on execution and resource navigation
- move bulky examples and variant-specific material into references

## 5. Package The Skill

Package and validate with:

```bash
scripts/package_skill.py <path/to/skill-folder>
```

Optional output directory:

```bash
scripts/package_skill.py <path/to/skill-folder> ./dist
```

The packaging step validates:

- frontmatter format
- naming and directory structure
- description quality
- file organization and resource references

Fix validation errors before packaging again.

## 6. Iterate

Use the skill on real tasks, notice where it struggles, then update `SKILL.md` or bundled resources accordingly. Prefer improvements driven by observed failure modes over speculative additions.
