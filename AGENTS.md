# Repository Guidelines

This repository is the reusable `nix-agents` engine. Keep concrete personal or organization-specific agent configuration in a consuming flake.

## Source Layout

- `modules/`: Nix module option declarations.
- `lib/core/`: evaluation and builder APIs.
- `lib/generators/`: target-specific config generators.
- `lib/schemas/`: compatibility schemas and fixtures.
- `checks/`: structural eval checks used by `nix flake check`.
- `templates/`: starter flake templates for consumers.

## Development Commands

- `nix flake check`
- `nix run .#fmt`
- `nix run .#lint`
- `nix run .#bench`

## Design Rules

- Keep the public API in `lib/default.nix` stable where possible.
- Keep generated output behavior target-specific in `lib/generators/`.
- Keep wrapper runtime behavior in `lib/core/builders.nix`.
- Do not add personal agents, skills, profiles, secrets, or service packages to this repo.
- Add concrete examples to `templates/`, not as default exported presets.
