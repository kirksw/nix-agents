{
  skills.nix-flake-ops = {
    description = "Practical patterns for multi-output flakes and package composition.";
    content = ''
      # nix-flake-ops

      Use this skill when editing flakes:

      - Keep `eachDefaultSystem` composition simple.
      - Expose reusable library modules from `lib`.
      - Return deterministic, pure outputs.
      - Keep runtime wrappers separate from pure evaluation.
    '';
    resources = { };
    src = null;
  };
}
