{
  lib,
  config,
  src ? null,
}:
let
  opencodeGenerator = import ./opencode.nix { inherit lib config; };
  agentsMdGenerator = import ./agents-md.nix { inherit lib; };

  workflowGuide = if src != null then builtins.readFile "${src}/AGENTS.md" else "";
in
{
  inherit (opencodeGenerator) agents skills mcpJson;
  agentsMd = workflowGuide;
  agentListMd = agentsMdGenerator { inherit (config) agents; };

  extensions = if src != null then "${src}/targets/pi/extensions" else null;
  prompts = if src != null then "${src}/targets/pi/prompts" else null;
}
