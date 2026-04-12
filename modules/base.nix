{ lib, types, ... }:
{
  options.bases = lib.mkOption {
    type = types.bases;
    default = { };
    description = ''
      Named runtime bases. Each base represents a security/account/environment
      boundary that owns shared runtime state (credentials, auth, sessions).
      Profiles are configuration overlays within a base.
    '';
  };
}
