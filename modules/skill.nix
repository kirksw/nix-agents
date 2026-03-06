{ lib, types, ... }:
{
  options.skills = lib.mkOption {
    type = types.skills;
    default = { };
    description = "Configured skills available to agents.";
  };
}
