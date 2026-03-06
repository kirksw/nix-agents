{ lib, types, ... }:
{
  options.agents = lib.mkOption {
    type = types.agents;
    default = { };
    description = "The configured agent graph.";
  };
}
