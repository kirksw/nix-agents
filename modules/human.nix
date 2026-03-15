{ lib, types, ... }:
{
  options.human = lib.mkOption {
    type = types.humanType;
    default = { };
    description = "Human operator context injected as preamble into all agent prompts.";
  };
}
