# Omnigent Meta-Harness Takeaways

These notes capture what is worth borrowing from Omnigent for `nix-agents` without adopting Omnigent as a higher-level runtime.

## Direction

Use Pi as the orchestration surface, but keep `nix-agents` as a generator:

- Define agents, skills, workflows, and launch affordances declaratively in Nix.
- Generate target-specific config for Pi, Claude, Codex, etc.
- Let Pi/local assistant sessions kick off workflows conversationally.
- Avoid adding a new cross-harness execution runtime unless static generation proves insufficient.

## Omnigent patterns worth copying

### Bundle agent-local context

Omnigent bundles an agent directory into a session-scoped artifact:

```text
config.yaml
agents/<name>/config.yaml
skills/<name>/SKILL.md
tools/...
```

This avoids relying only on ambient user config. For `nix-agents`, the equivalent is generated per-profile or per-workflow config directories containing the required agents and skills.

### Spawn declared subagents only

Omnigent exposes subagent spawning through `sys_session_send`, limited by the parent spec's declared `tools.agents`. A child gets its own session and its own harness from `agents/<name>/config.yaml`.

Pi already has a similar shape through `subagent`; prefer generating Pi launch recipes/prompts/chains rather than inventing another runtime.

### Pass per-spawn config explicitly

Omnigent passes harness-specific config through per-spawn environment variables such as `HARNESS_CODEX_*`, `HARNESS_CLAUDE_SDK_*`, and `HARNESS_PI_*`.

For `nix-agents`, prefer explicit generated launch environments/config roots over mutating user-level config.

## Native harness isolation notes

### Codex native

Codex is the clean model:

- create a private per-session `CODEX_HOME`
- copy `config.toml`
- bridge/symlink auth as needed
- inject skills, hooks, MCP relay, and provider overrides into that private home

This avoids polluting the user's real `~/.codex` session/config state.

### Claude native

Claude is only partially scoped:

- pass per-launch `--mcp-config`
- pass per-launch `--settings`
- pass bundled skills with `--plugin-dir`
- optionally suppress host skills with `--setting-sources ""`

Claude still uses normal user state such as `~/.claude.json` and project/session storage. Do not assume full home isolation for Claude native.

## Tool surfaces Omnigent injects

Common runtime tools include:

- skill loading: `load_skill`, `read_skill_file`
- async work: `sys_call_async`, `sys_read_inbox`, `sys_cancel_async`
- subagent/session control: `sys_session_send`, `sys_session_list`, `sys_session_get_history`, `sys_session_get_info`, `sys_session_close`, `sys_session_create`
- OS access when enabled: `sys_os_read`, `sys_os_write`, `sys_os_edit`, `sys_os_shell`
- terminals when enabled: `sys_terminal_launch`, `sys_terminal_send`, `sys_terminal_read`, `sys_terminal_list`, `sys_terminal_close`
- agent discovery: `sys_agent_get`, `sys_agent_download`, `sys_agent_list`
- policy/comments: `sys_add_policy`, `sys_policy_registry`, `list_comments`, `update_comment`
- optional builtins: `web_search`, `web_fetch`, `upload_file`, `list_files`, `download_file`, `search_conversations`, `export_agent`

MCP tools are namespaced as:

```text
<server_name>__<tool_name>
```

This avoids collisions when multiple MCP servers expose the same tool name.

## Sandboxing takeaways

Omnigent separates orchestration from OS sandboxing.

For `sys_os_*`, it runs a helper process wrapped by a platform sandbox:

- Linux: `bwrap`
- macOS: `sandbox-exec`
- explicit opt-out: `sandbox.type = none`

The sandbox controls read roots, write roots/files, network access, hidden dotfiles, environment passthrough, private temp dirs, egress proxying, and credential proxying.

Important defaults:

- avoid mounting `$HOME`
- strip secret environment variables by default
- make cwd read-only unless explicitly writable
- require explicit env passthrough for credentials

For `nix-agents`, keep sandboxing as target/wrapper policy, not as workflow semantics.

## Recommended `nix-agents` slice

Start small:

1. Add or document a static workflow/launch-manifest concept.
2. Generate Pi-first orchestration affordances.
3. Generate scoped target config directories for spawned Claude/Codex/Pi sessions.
4. Copy Codex's private-home pattern where possible.
5. For Claude, use per-launch args and make the shared-state caveat explicit.

Skip for now:

- persistent workflow runtime
- retries/state machines/inbox implementation
- cross-harness semantic parity
- dynamic arbitrary agent spawning
- dashboards/registries/metrics

## Decision rule

If a workflow can be represented as generated config plus a Pi launch prompt/chain, keep it declarative. Add runtime machinery only after several real workflows prove static generation cannot express the needed behavior.
