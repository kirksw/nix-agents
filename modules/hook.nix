{ lib, types, ... }:
{
  options.hooks = lib.mkOption {
    type = types.hooks;
    default = [ ];
    description = "Hooks triggered on agent system events.";
  };
}
