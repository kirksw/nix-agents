{ lib }:
{ agents }:
let
  agentNames = builtins.attrNames agents;

  nodeId = name: builtins.replaceStrings [ "-" ] [ "_" ] name;

  nodeLines = map (
    name:
    let
      agent = agents.${name};
      id = nodeId name;
    in
    if agent.mode == "primary" then "  ${id}([${name}])" else "  ${id}[${name}]"
  ) agentNames;

  edgeLines = lib.concatMap (
    name:
    let
      agent = agents.${name};
      fromId = nodeId name;
    in
    map (to: "  ${fromId} --> ${nodeId to}") agent.delegatesTo
  ) agentNames;
in
lib.concatStringsSep "\n" ([ "graph TD" ] ++ nodeLines ++ edgeLines)
