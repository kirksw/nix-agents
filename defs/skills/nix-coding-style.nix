{
  skills.nix-coding-style = {
    description = "Nix code formatting and style conventions for nixfiles-v2. Use when writing or reviewing Nix code.";
    content = ''
      # Nix Coding Style

      Follow these conventions when writing Nix code in this repository.

      ## Formatting

      - Use 2-space indentation
      - Use trailing commas in attribute sets and lists
      - Format files with `nixfmt` before committing

      ## Module Structure

      ```nix
      {
        lib,
        config,
        pkgs,
        ...
      }:

      {
        options = {
          homeModules.<name>.enable = lib.mkEnableOption "description";
        };

        config = lib.mkIf config.homeModules.<name>.enable {
          # implementation
        };
      }
      ```

      ## Option Naming

      - Use prefixed namespaces:
        - `homeModules.<name>.enable`
        - `darwinModules.<name>.enable`
        - `nixosModules.<name>.enable`
      - Multi-word options use camelCase: `homeModules.aiDev.enable`

      ## File Organization

      - One module per file: `modules/home/programs/<tool>.nix`
      - Group related options together
      - Keep modules focused and composable

      ## Common Patterns

      ### Conditional config
      ```nix
      config = lib.mkIf config.homeModules.<name>.enable {
        # settings
      };
      ```

      ### Optional attributes
      ```nix
      config = {
        # always present
      } // lib.optionalAttrs config.homeModules.<name>.enable {
        # optional
      };
      ```

      ### Package reference
      ```nix
      home.packages = [ pkgs.<package> ];
      ```

      ### File generation
      ```nix
      home.file."path/to/file".text = builtins.toJSON config;
      ```

      ## Testing

      Run before committing:
      ```bash
      nixfmt --check **/*.nix
      statix check
      nix flake check --no-build
      ```
    '';
    resources = { };
    src = null;
  };
}
