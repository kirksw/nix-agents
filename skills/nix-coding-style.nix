{
  skills.nix-coding-style = {
    description = "Shared conventions for Nix and flake-style formatting.";
    content = ''
      # nix-coding-style

      Keep Nix files readable with:
      - 2-space indentation
      - Explicit braces and commas
      - Named helper functions for repeated logic
      - Short attribute names only where clarity is preserved
    '';
    resources = { };
    src = null;
  };
}
