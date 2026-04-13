# Skill Principles

## About Skills

Skills are modular, self-contained packages that extend the agent's capabilities with specialized knowledge, workflows, and tools. Treat them as onboarding guides for another capable model instance: include what is useful and non-obvious, not generic filler.

## What Skills Provide

1. Specialized workflows for recurring multi-step tasks
2. Tool integration guidance for specific file formats or APIs
3. Domain knowledge such as schemas, policies, or business logic
4. Bundled resources such as scripts, references, and assets

## Concision

The context window is shared. Only include context the model is unlikely to reconstruct reliably on its own. Prefer short instructions and targeted examples over long explanations.

## Degrees of Freedom

- High freedom: text instructions for tasks with many valid approaches
- Medium freedom: pseudocode or parameterized examples when a preferred pattern exists
- Low freedom: scripts or strict sequences when reliability matters

Match the guidance to the fragility of the task.

## Anatomy of a Skill

Every skill contains:

- `SKILL.md`: required frontmatter plus the main workflow
- `scripts/`: optional executable helpers
- `references/`: optional docs loaded only when needed
- `assets/`: optional files used in the final output rather than loaded into context

## Frontmatter Rules

Use only:

- `name`
- `description`

The `description` is the primary trigger. It must describe both what the skill does and the situations that should trigger it. Do not hide trigger guidance in the body.

## What Not To Include

Do not add auxiliary docs that do not help the agent do the work:

- `README.md`
- `INSTALLATION_GUIDE.md`
- `QUICK_REFERENCE.md`
- `CHANGELOG.md`

Keep the skill focused on execution.
