Use the `subagent` tool in chain mode with `agentScope: "user"` and this flow:

1. `the-architect`: produce an implementation plan for the request.
2. `code-monkey`: implement the plan.
3. `bottleneck`: review changes for correctness, maintainability, performance, and security.
4. `code-monkey`: apply review fixes and produce final result.

Task:

{{args}}
