# Renders a model-tier manifest as markdown, derived solely from data already
# computed during generation: `tierModels` (resolved generatorDefaults //
# config.tierMapping) and `config.agents` (each agent's `model` field, which is
# either a tier key or a concrete model id).
#
# The manifest lets downstream agents reason about tier peers for sparring,
# backup failover, and peer review. See docs/adr/ADR-0003-generated-tier-manifest.md.
{ lib }:
{
  agents,
  tierModels,
}:
let
  tierOrder = [
    "ultrafast"
    "fast"
    "balanced"
    "powerful"
    "reasoning"
  ];

  # Tiers actually present in the resolved tierMapping, in canonical order,
  # followed by any extra keys not in the canonical order (sorted).
  knownTiers = builtins.filter (t: tierModels ? ${t}) tierOrder;
  extraTiers = lib.sort (a: b: a < b) (
    builtins.filter (t: !(builtins.elem t tierOrder)) (builtins.attrNames tierModels)
  );
  orderedTiers = knownTiers ++ extraTiers;

  # Classify each agent: is its `model` a tier key, or a concrete model id?
  # A "tier key" is any key present in tierModels.
  agentTier = agent: if tierModels ? ${agent.model} then agent.model else "other";

  agentsByTier = lib.foldl' (
    acc: name:
    let
      agent = agents.${name};
      t = agentTier agent;
    in
    acc // { ${t} = (acc.${t} or [ ]) ++ [ name ]; }
  ) { } (builtins.attrNames agents);

  # Render a single tier group. `tier` is a tier key; `model` is its resolved
  # concrete id (for the "other" group, there is no single model so we omit it).
  renderGroup =
    tier:
    let
      members = agentsByTier.${tier} or [ ];
      model = tierModels.${tier} or null;
      heading = if model != null then "**${tier}** — ${model}" else "**${tier}**";
      memberLine = lib.concatStringsSep ", " (map (n: "`${n}`") members);
    in
    if members == [ ] then
      ""
    else
      ''
        #### ${heading}

        ${memberLine}'';

  groups = lib.concatStringsSep "\n\n" (builtins.filter (s: s != "") (map renderGroup orderedTiers));

  # "other" group: agents whose model is a concrete id (not a tier key).
  otherGroup =
    let
      others = agentsByTier.other or [ ];
      lines = map (n: "- `${n}` — `${agents.${n}.model}`") others;
    in
    if others == [ ] then
      ""
    else
      ''
        #### Other (concrete model ids)

        ${lib.concatStringsSep "\n" lines}'';

  tierTableRows = lib.concatStringsSep "\n" (map (t: "| ${t} | ${tierModels.${t}} |") orderedTiers);

  body = lib.concatStringsSep "\n\n" (
    builtins.filter (s: s != "") [
      groups
      otherGroup
    ]
  );
in
''
  <!-- nix-agents:tier-manifest:start -->
  ## Model Tiers (generated)

  Tier keys resolve to concrete models per-profile from `tierMapping`. Each agent's
  `model` field is a tier key resolved at generation time.

  ### Tier → model

  | Tier | Resolved model |
  |------|----------------|
  ${tierTableRows}

  ### Agents by tier

  Agents grouped by their model tier key. Agents in the same group run peer-strength
  models and are suitable for sparring, backup failover, or peer review of each other's
  work.

  ${body}

  ### Using this

  - **Sparring**: pick two agents from the same tier (e.g. two `powerful` agents).
  - **Backup failover**: if an agent fails or stalls, delegate to another agent in the
    same tier so model strength is preserved.
  - **Peer review**: have a same-tier agent review another's plan or work.

  > Model tier (`fast`/`balanced`/`powerful`/`reasoning`) is distinct from organizational
  > tier (`employee`/`manager`/`orchestrator`).
  <!-- nix-agents:tier-manifest:end -->
''
