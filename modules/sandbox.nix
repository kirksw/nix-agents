{ lib, types, ... }:
{
  options.sandboxes = lib.mkOption {
    type = types.sandboxes;
    default = { };
    description = ''
      Named OpenShell sandbox launch configurations. Profiles opt into one of
      these configs through `profiles.<name>.sandbox`.
    '';
  };
}
