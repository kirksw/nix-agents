{ lib }:
{ agents }:
let
  agentNames = builtins.attrNames agents;

  mermaidGenerator = import ./mermaid.nix { inherit lib; };
  mermaidGraph = mermaidGenerator { inherit agents; };

  patternEntries = lib.foldl' (
    acc: name:
    let
      agent = agents.${name};
      entries = lib.mapAttrsToList (
        pattern: body: "- **${name}** - ${pattern}\n\n  ${body}\n"
      ) agent.orchestration.patterns;
    in
    acc ++ entries
  ) [ ] agentNames;

  antiPatterns = lib.concatMap (name: agents.${name}.orchestration.antiPatterns or [ ]) agentNames;

  byDelegate = map (
    agentName:
    let
      agent = agents.${agentName};
      delegates = lib.concatStringsSep ", " (map (n: "`${n}`") agent.delegatesTo);
      line = if agent.delegatesTo == [ ] then "no explicit delegates" else delegates;
    in
    "- `${agentName}` delegates to ${line}"
  ) agentNames;
in
''
  # AGENTS Orchestration

  This document is generated from the agent graph definition.

  ## Delegation Graph

  ```mermaid
  ${mermaidGraph}
  ```

  ## When to delegate

  ${lib.concatStringsSep "\n" byDelegate}

  ## Effective patterns

  ${
    if patternEntries == [ ] then
      "No orchestration patterns were defined."
    else
      lib.concatStringsSep "\n" patternEntries
  }

  ## Anti-patterns

  ${
    if antiPatterns == [ ] then
      "- None."
    else
      lib.concatStringsSep "\n" (map (p: "- ${p}") antiPatterns)
  }
''
