Use the `subagent` tool in chain mode with `agentScope: "user"` and this flow:

1. `code-monkey`: implement the requested change.
2. `bottleneck`: review for correctness, maintainability, performance, and security.
3. `code-monkey`: resolve review findings and produce a final patch summary.

Task:

{{args}}
