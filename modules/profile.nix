{ lib, types, ... }:
{
  options.profiles = lib.mkOption {
    type = types.profiles;
    default = { };
    description = "Named runtime profiles. Each produces a separate generated config store path.";
  };
}
