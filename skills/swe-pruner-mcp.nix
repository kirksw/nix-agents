{
  skills.swe-pruner-mcp = {
    description = "Use the Swe-Pruner MCP tools for compact code scanning and search.";
    content = ''
      # swe-pruner-mcp

      Use MCP tools exposed by this skill to scan for high-signal files and reduce context overhead.

      - Read focused code slices before broader edits.
      - Prefer pruned search for large repositories.
    '';
    resources = { };
    src = null;
  };
}
