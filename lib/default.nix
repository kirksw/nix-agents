{ lib }:
let
  types = import ./core/types.nix { inherit lib; };
  evalModules = import ./core/eval.nix { inherit lib types; };
  builders = import ./core/builders.nix { inherit lib evalModules; };
in
{
  inherit types evalModules;
  inherit (builders)
    mkAgentSystem
    mkProfileMeta
    mkWrappedTool
    resolveBaseProfile
    ;
}
