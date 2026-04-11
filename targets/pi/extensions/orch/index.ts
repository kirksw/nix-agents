/**
 * Orchestrator Command Extension
 *
 * Registers the /orch slash command that routes user requests through
 * the 3-tier agent architecture (orchestrator → manager → employee).
 *
 * Usage: /orch implement feature X
 *        /orch review the auth module
 *        /orch write an ADR for the caching strategy
 *
 * The command sends a user message that instructs the agent to delegate
 * the task to the orchestrator subagent.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("orch", {
    description:
      "Route a request through the orchestrator (3-tier architecture). Usage: /orch <task description>",

    handler: async (args, ctx) => {
      const task = (args || "").trim();

      if (!task) {
        ctx.ui.notify("Usage: /orch <task description>", "warning");
        return;
      }

      // sendUserMessage is on ExtensionAPI (pi), not on ctx.
      // It sends a user message that triggers a full agent turn.
      pi.sendUserMessage(
        `Use the subagent tool to delegate this task to the orchestrator:\n\n${task}`,
      );
    },
  });
}
