{ lib, config, ... }:
let
  normalizePermissionSet =
    permission:
    if builtins.isString permission then
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

  allValid =
    checkDelegatesExist && checkNoSelfDelegation && checkTaskPerms && checkSkillRefs && checkMcpRefs;
in
{
  options._validated = lib.mkOption {
    type = lib.types.bool;
    default = allValid;
    internal = true;
    description = "Internal option that forces graph validation at eval time.";
  };
}
