{ lib, types, ... }:
{
  options.providers = lib.mkOption {
    type = types.providers;
    default = { };
    description = "Named credential providers referenced by profiles.";
  };
}
