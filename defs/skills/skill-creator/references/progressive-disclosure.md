# Progressive Disclosure

## Loading Model

Skills should be organized so the model only loads what it needs:

1. Metadata: always visible
2. `SKILL.md`: loaded when the skill triggers
3. Bundled resources: loaded only when needed

Keep `SKILL.md` under roughly 500 lines where practical. Move detailed material into references before the main body becomes hard to scan.

## Split Patterns

### High-Level Guide Plus References

Use a short `SKILL.md` with links to deeper material:

- basic workflow in `SKILL.md`
- advanced forms, APIs, or examples in `references/*.md`

### Domain-Based Splits

When the skill spans multiple domains, split by domain:

- `references/finance.md`
- `references/sales.md`
- `references/product.md`

### Variant-Based Splits

When the skill spans multiple providers or frameworks, split by variant:

- `references/aws.md`
- `references/gcp.md`
- `references/azure.md`

### Conditional Details

Keep the common path in `SKILL.md` and link to advanced references only for special cases such as tracked changes, redlining, or compliance edge cases.

## Rules For References

- Keep references one level deep from `SKILL.md`
- Link to references directly from `SKILL.md`
- Avoid duplicating the same information in both places
- Add a brief table of contents if a reference file gets long

## When To Use Scripts

Add `scripts/` when:

- the same code is being rewritten repeatedly
- output must be deterministic
- execution is cheaper than re-explaining logic in markdown

Scripts should still be simple to inspect and patch if needed.
