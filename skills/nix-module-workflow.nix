{
  skills.nix-module-workflow = {
    description = "Composable Nix module patterns for teams and teams of agents.";
    content = ''
      # nix-module-workflow

      Recommended workflow:

      - Use `lib.evalModules` to compose reusable config.
      - Put assertions in `system` module.
      - Generate artifacts in separate builders for each target.
      - Keep generated outputs versioned as deterministic files.
    '';
    resources = { };
    src = null;
  };
}
