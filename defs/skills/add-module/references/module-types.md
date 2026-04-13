# Module Types

Use this when helping the user choose what they want to add.

1. Agent: an LLM persona with a role, model tier, prompt, permissions, and optional delegates, skills, and MCP servers
2. Skill: a reusable workflow or domain guide exposed through the skill system
3. MCP server: a local or remote Model Context Protocol server that provides tools or data
4. Hook: a shell script triggered on lifecycle events such as session start, delegation, commit, or error
5. Preset: a curated `imports` bundle that groups agents, skills, and MCP servers
6. Profile: a runtime context keyed by path prefixes that filters active agents, skills, and MCP servers

When the user is unsure, ask what outcome they want:

- new persona or role: agent
- reusable guidance or workflow: skill
- new tool or external integration: MCP server
- event-driven shell behavior: hook
- reusable bundle of existing modules: preset
- directory-specific activation and filtering: profile
