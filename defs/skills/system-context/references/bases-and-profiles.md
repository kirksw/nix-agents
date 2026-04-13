# Bases And Profiles

## Mental Model

- Base = environment boundary with shared runtime state such as credentials, auth, and sessions
- Profile = configuration overlay inside a base

Canonical naming is `<base>/<profile>`.

## Bases On This Machine

### `personal`

- path prefixes:
  - `~/src/`
  - `~/projects/`
- default profile: `stable`
- providers:
  - `personal-zai-key`
  - `personal-minimax-key`

### `work`

- path prefixes:
  - `~/git/github.com/lunarway/`
  - `~/projects/lunar/`
- default profile: `default`

## Profiles In This Repo

### `personal-default`

- base: `personal`
- agents: all
- skills: all
- MCP servers: all

### `work-default`

- base: `work`
- restricted agent set
- skills:
  - `nix-agents`
  - `system-context`
- webfetch denied by default

## Resolution Rules

Profile selection prefers, in order:

1. an explicit forced profile if the wrapper was invoked that way
2. a `.nix-agents-profile` file in the current directory or one of its parents
3. path-prefix matching against configured base and profile prefixes
4. fallback to `personal-default` when available

That fallback means personal projects outside known prefixes still get a valid profile.

## Directory Shape

Generated config is organized as:

- `~/.config/nix-agents/<target>/bases/<base>/profiles/<profile>/`

Base state is isolated, especially between `personal/*` and `work/*`.
