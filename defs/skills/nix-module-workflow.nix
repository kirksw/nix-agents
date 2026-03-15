{
  skills.nix-module-workflow = {
    description = "Add or modify nix modules in nixfiles-v2, wire them into hosts, and validate safely. Use when users ask to add programs, services, overlays, or host configuration.";
    content = ''
      # Nix Module Workflow

      Use this skill when implementing configuration changes in `modules/`, `hosts/`, `packages/`, or `overlays/`.

      ## Where to Change What

      - User program/service config: `modules/home/programs/*.nix`, `modules/home/services/*.nix`
      - macOS-specific behavior: `modules/darwin/*`
      - Linux-specific behavior: `modules/nixos/*`
      - Host wiring: `hosts/darwin/work/*.nix`, `hosts/nixos/*`
      - Shared defaults/helpers: `modules/shared/*`, `lib/*`

      ## Module Pattern

      Follow `modules/*/template.nix` style:

      1. Define `options.<path>.enable = lib.mkEnableOption ...`
      2. Gate config with `lib.mkIf config.<path>.enable { ... }`
      3. Keep modules focused and composable.

      ## Change Procedure

      1. Prefer editing an existing module before creating a new one.
      2. Add or update options and implementation.
      3. Enable module in the target host/home config.
      4. Validate with `nix flake check` and relevant build command.
      5. Apply with `switch` only after successful build.

      ## Naming and Layout

      - Use feature-based filenames: `modules/home/programs/<tool>.nix`
      - Keep host names explicit (`lunar`, `nixos-ry6a`)
      - Put custom packages in `packages/<name>/default.nix`
      - Put overlays in `overlays/<name>/default.nix`
    '';
    resources = { };
    src = null;
  };
}
