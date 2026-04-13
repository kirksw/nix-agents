# Layout

## Main Repo

Primary repo:

- `/Users/kisw/git/github.com/kirksw/nix-agents/main`

Important areas in that repo:

- `defs/agents/`
- `defs/skills/`
- `defs/mcps/`
- `defs/hooks/`
- `presets/`
- `modules/`
- `lib/`
- `checks/`

## Generated Config Root

Generated tool configs live under:

- `~/.config/nix-agents/<tool>/bases/<base>/profiles/<profile>/`

Examples:

- `~/.config/nix-agents/codex/bases/personal/profiles/personal-default/`
- `~/.config/nix-agents/claude/bases/work/profiles/work-default/`

## Tool-Specific Notes

- Codex, Claude, and OpenCode consume generated assets from the `~/.config/nix-agents/...` tree.
- Pi also has base-scoped shared state under `~/.config/nix-agents/pi/bases/<base>/state/`.

## Session Data

Session files are written under:

- `~/.local/share/nix-agents/sessions/<profile>/<project>/`

There is also transient wrapper state under:

- `~/.local/share/nix-agents/state/<wrapper-pid>/`

## Current Personal Codex Skill Location

An example of the currently synced personal Codex profile tree is:

- `~/.config/nix-agents/codex/bases/personal/profiles/personal-default/`

That is useful for inspection, but lasting changes should normally be made in the repo and re-synced.
