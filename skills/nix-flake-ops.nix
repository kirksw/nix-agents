{
  skills.nix-flake-ops = {
    description = "Build, check, switch, rollback, and update this nixfiles-v2 flake on macOS and NixOS. Use when users ask to validate or apply system configuration changes.";
    content = ''
      # Nix Flake Operations

      Use this skill for operational workflows in this repository.

      ## Repo-Specific Commands

      - macOS build only: `apps/aarch64-darwin/build`
      - macOS apply: `apps/aarch64-darwin/switch`
      - macOS rollback: `apps/aarch64-darwin/rollback`
      - NixOS apply: `apps/x86_64-linux/switch <hostname>`
      - Global checks: `nix flake check`
      - Update lockfile: `nix flake update [input]`
      - Update custom packages: `nix run .#update-packages`

      ## Workflow

      1. Run `nix flake check` for baseline validation.
      2. Build the target system before switching.
      3. Switch/apply only after build success.
      4. If change impacts versions, update with `nix flake update` and re-check.
      5. For package updates under `packages/*`, run `nix run .#update-packages`.

      ## Guardrails

      - Prefer `build` before `switch`.
      - Do not edit generated symlink `result`.
      - Keep changes host-aware (`lunar`, `nixos-ry6a`).
      - If command wrappers are missing for a target platform, use direct `nixos-rebuild`/`darwin-rebuild` with `--flake`.
    '';
    resources = { };
    src = null;
  };
}
