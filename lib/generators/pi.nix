{
  lib,
  config,
  src ? null,
  ...
}:
let
  opencodeGenerator = import ./opencode.nix { inherit lib config; };
  agentsMdGenerator = import ./agents-md.nix { inherit lib; };

  workflowGuide =
    if src != null then
      builtins.unsafeDiscardStringContext (builtins.readFile (src + "/AGENTS.md"))
    else
      "";
  # Append the generated model-tier manifest so pi can reason about tier peers
  # (sparring, backup failover, peer review). See ADR-0003.
  piAgentsMd =
    if workflowGuide != "" then
      workflowGuide + "\n\n" + opencodeGenerator.tierManifest
    else
      opencodeGenerator.tierManifest;
in
{
  inherit (opencodeGenerator) agents skills mcpJson;
  agentsMd = piAgentsMd;
  agentListMd = agentsMdGenerator { inherit (config) agents; };

  extensions =
    if src != null then
      builtins.path {
        path = src + "/targets/pi/extensions";
        name = "pi-extensions";
      }
    else
      null;
  prompts =
    if src != null then
      builtins.path {
        path = src + "/targets/pi/prompts";
        name = "pi-prompts";
      }
    else
      null;
}
