# Source Of Truth

## Default Rule

This machine is Nix-oriented. Prefer persistent changes in the declarative source of truth rather than editing generated files in place.

## For `nix-agents`

The primary source repo is:

- `/Users/kisw/git/github.com/kirksw/nix-agents/main`

When behavior changes should apply to generated agent configs, make the change in the repo:

- `defs/` for agents, skills, MCP servers, and hooks
- `presets/` for import bundles and profile/base setup
- `lib/` and `modules/` for shared logic and option semantics
- `flake.nix` for outputs, sync flow, checks, and wrapper wiring

Then rebuild or sync rather than hand-editing generated output.

## For Broader System Configuration

The main machine-level Nix configuration repo is:

- `/Users/kisw/git/github.com/kirksw/nix-config`

Use that repo when the requested change is about broader system setup rather than `nix-agents` behavior, for example:

- packages installed on the machine
- shell or editor configuration managed outside `nix-agents`
- system services
- Home Manager or nix-darwin style user/system configuration

If a request touches both agent behavior and machine setup, decide which repo owns which part rather than forcing everything into one place.

## Generated Output

Treat these as generated artifacts, not the primary place to make lasting edits:

- `~/.config/nix-agents/<tool>/bases/<base>/profiles/<profile>/...`

Those directories are populated by generated configs and sync logic. If you change files there manually, the next sync or rebuild can overwrite them.

## Practical Decision Rule

If the question is:

- "How should this tool behave?" -> change Nix source
- "Which agents/skills/profiles should be active?" -> change Nix source
- "How should this machine be configured?" -> usually change `/Users/kisw/git/github.com/kirksw/nix-config`
- "Where does this generated file live right now?" -> inspect generated output
- "Why is the active config resolving this way?" -> inspect bases, profiles, path prefixes, and `.nix-agents-profile`

## For Non-`nix-agents` Persistent Setup

If a requested change looks like machine setup, package installation, shell behavior, or other recurring configuration, first ask whether there is a Nix-managed source of truth for it instead of editing local runtime state directly.
