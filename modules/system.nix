{ lib, config, ... }:
let
  normalizePermissionSet =
    permission:
    if permission == null then
      {
        default = "deny";
        rules = { };
      }
    else if builtins.isString permission then
      {
        default = permission;
        rules = { };
      }
    else
      permission;

  agentNames = builtins.attrNames config.agents;

  checkDelegatesExist =
    let
      delegates = lib.concatMap (
        a:
        map (to: {
          from = a;
          inherit to;
        }) config.agents.${a}.delegatesTo
      ) agentNames;
      bad = lib.filter (d: !builtins.elem d.to agentNames) delegates;
    in
    if bad != [ ] then
      throw "delegatesTo targets do not exist: ${
        lib.concatMapStringsSep ", " (d: "${d.from} -> ${d.to}") bad
      }"
    else
      true;

  checkNoSelfDelegation =
    let
      bad = lib.filter (a: builtins.elem a config.agents.${a}.delegatesTo) agentNames;
    in
    if bad != [ ] then
      throw "Agents cannot delegate to themselves: ${lib.concatStringsSep ", " bad}"
    else
      true;

  checkTaskPerms =
    let
      taskRefs = lib.flatten (
        map (
          a:
          let
            perms = normalizePermissionSet config.agents.${a}.permissions.task;
          in
          builtins.attrNames perms.rules
        ) agentNames
      );
      bad = lib.filter (t: !builtins.elem t agentNames) taskRefs;
    in
    if bad != [ ] then
      throw "Task permission rules reference nonexistent agents: ${lib.concatStringsSep ", " bad}"
    else
      true;

  checkSkillRefs =
    let
      allSkills = builtins.attrNames config.skills;
      refs = lib.concatMap (a: config.agents.${a}.skills) agentNames;
      bad = lib.filter (s: !builtins.elem s allSkills) refs;
    in
    if bad != [ ] then
      throw "Referenced skills not defined: ${lib.concatStringsSep ", " bad}"
    else
      true;

  checkMcpRefs =
    let
      allMcp = builtins.attrNames config.mcpServers;
      refs = lib.concatMap (a: config.agents.${a}.mcpServers) agentNames;
      bad = lib.filter (s: !builtins.elem s allMcp) refs;
    in
    if bad != [ ] then
      throw "Referenced MCP servers not defined: ${lib.concatStringsSep ", " bad}"
    else
      true;

  checkManagedSubset =
    let
      bad = lib.concatMap (
        name:
        let
          agent = config.agents.${name};
          notInDelegates = lib.filter (m: !builtins.elem m agent.delegatesTo) agent.managedAgents;
        in
        map (m: "${name}.managedAgents: ${m} not in delegatesTo") notInDelegates
      ) agentNames;
    in
    if bad != [ ] then
      throw "managedAgents must be a subset of delegatesTo: ${lib.concatStringsSep ", " bad}"
    else
      true;

  checkProfileRefs =
    let
      profileNames = builtins.attrNames config.profiles;
      allAgents = builtins.attrNames config.agents;
      allSkills = builtins.attrNames config.skills;
      allMcp = builtins.attrNames config.mcpServers;
      allProviders = builtins.attrNames config.providers;

      badAgents = lib.concatMap (
        p:
        map (a: "${p}.agents: ${a}") (
          lib.filter (a: !builtins.elem a allAgents) config.profiles.${p}.agents
        )
      ) profileNames;

      badSkills = lib.concatMap (
        p:
        map (s: "${p}.skills: ${s}") (
          lib.filter (s: !builtins.elem s allSkills) config.profiles.${p}.skills
        )
      ) profileNames;

      badMcp = lib.concatMap (
        p:
        map (m: "${p}.mcpServers: ${m}") (
          lib.filter (m: !builtins.elem m allMcp) config.profiles.${p}.mcpServers
        )
      ) profileNames;

      badProviders = lib.concatMap (
        p:
        map (pr: "${p}.providers: ${pr}") (
          lib.filter (pr: !builtins.elem pr allProviders) config.profiles.${p}.providers
        )
      ) profileNames;

      bad = badAgents ++ badSkills ++ badMcp ++ badProviders;
    in
    if bad != [ ] then
      throw "Profile references do not exist: ${lib.concatStringsSep ", " bad}"
    else
      true;

  # ADR-0001: Every profile that declares a base must reference an existing base.
  checkBaseExistence =
    let
      baseNames = builtins.attrNames config.bases;
      profileNames = builtins.attrNames config.profiles;
      # Only check profiles that explicitly set a base field
      explicitProfiles = lib.filter (p: config.profiles.${p}.base != null) profileNames;
      bad = lib.filter (p: !builtins.elem config.profiles.${p}.base baseNames) explicitProfiles;
    in
    if bad != [ ] then
      throw "Profiles reference nonexistent bases: ${
        lib.concatStringsSep ", " (map (p: "${p} -> ${config.profiles.${p}.base}") bad)
      }"
    else
      true;

  # ADR-0001: No two bases may share the same stateDir override.
  checkBaseStateDirUniqueness =
    let
      baseEntries = lib.filterAttrs (_: b: b.stateDir != null) config.bases;
      # Group bases by their stateDir
      byDir = lib.foldAttrs (name: _: [ name ]) [ ] (
        lib.mapAttrsToList (name: b: {
          name = b.stateDir;
          value = name;
        }) baseEntries
      );
      duplicates = lib.filterAttrs (_: names: builtins.length names > 1) byDir;
    in
    if duplicates != { } then
      throw "Bases share stateDir: ${
        lib.concatStringsSep ", " (
          lib.mapAttrsToList (dir: names: "${lib.concatStringsSep ", " names} -> ${dir}") duplicates
        )
      }"
    else
      true;

  # ADR-0001: Profile providers must be a subset of their base's providers
  # (when the profile declares a base and the base declares providers).
  # If a base has providers, profiles in that base must not reference providers
  # outside the base's set.
  checkCrossBaseProviders =
    let
      profileNames = builtins.attrNames config.profiles;
      allProviders = builtins.attrNames config.providers;
      checkProfile =
        p:
        let
          profile = config.profiles.${p};
          baseName = profile.base;
        in
        if baseName == null then
          [ ]
        else
          let
            baseCfg = config.bases.${baseName} or null;
          in
          if baseCfg == null || baseCfg.providers == [ ] then
            [ ]
          else
            let
              outsideBase = lib.filter (pr: !builtins.elem pr baseCfg.providers) profile.providers;
            in
            map (pr: "${p}.providers: ${pr} not in base ${baseName}") outsideBase;
      bad = lib.concatMap checkProfile profileNames;
    in
    if bad != [ ] then
      throw "Profile providers leak across base boundary: ${lib.concatStringsSep ", " bad}"
    else
      true;

  allValid =
    checkDelegatesExist
    && checkNoSelfDelegation
    && checkTaskPerms
    && checkSkillRefs
    && checkMcpRefs
    && checkProfileRefs
    && checkManagedSubset
    && checkBaseExistence
    && checkBaseStateDirUniqueness
    && checkCrossBaseProviders;
in
{
  options = {
    maxDelegationDepth = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "System-wide max delegation depth. Individual agents can override.";
    };

    tierMapping = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Override model tier to concrete model-string mappings.
        Keys: fast, balanced, powerful, reasoning.
        Generators merge these over their built-in defaults.
      '';
      example = {
        fast = "anthropic/claude-haiku-4-5-20251001";
        reasoning = "anthropic/claude-opus-4-6";
      };
    };

    defaultPermissions = lib.mkOption {
      type =
        let
          permEnum = lib.types.enum [
            "allow"
            "deny"
            "ask"
          ];
        in
        lib.types.submodule {
          options = {
            edit = lib.mkOption {
              type = permEnum;
              default = "deny";
            };
            bash = lib.mkOption {
              type = permEnum;
              default = "deny";
            };
            task = lib.mkOption {
              type = permEnum;
              default = "deny";
            };
            webfetch = lib.mkOption {
              type = permEnum;
              default = "deny";
            };
          };
        };
      default = { };
      description = "System-wide permission defaults. Generators use these as fallback for agents with null permissions.";
    };

    _validated = lib.mkOption {
      type = lib.types.bool;
      default = allValid;
      internal = true;
      description = "Internal option that forces graph validation at eval time.";
    };
  };
}
