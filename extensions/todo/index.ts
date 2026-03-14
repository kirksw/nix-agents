/**
 * Todo Extension - Demonstrates state management via session entries
 *
 * This extension:
 * - Registers a `todo` tool for the LLM to manage todos
 * - Registers a `/todos` command for users to view the list
 *
 * State is stored in tool result details (not external files), which allows
 * proper branching - when you branch, the todo state is automatically
 * correct for that point in history.
 */

import { StringEnum } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { matchesKey, Text, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

interface Todo {
  id: number;
  text: string;
  done: boolean;
}

interface TodoDetails {
  action: "list" | "add" | "toggle" | "clear";
  todos: Todo[];
  nextId: number;
  error?: string;
}

const MAX_TODOS = 200;
const MAX_TODO_TEXT_LENGTH = 280;

function cloneTodos(items: Todo[]): Todo[] {
  return items.map((todo) => ({ ...todo }));
}

function sanitizeTodoText(text: string): string {
  const cleaned = text
    .replace(/[\u0000-\u001f\u007f-\u009f\u001b]/g, "")
    .replace(/\s+/g, " ")
    .trim();
  return cleaned.slice(0, MAX_TODO_TEXT_LENGTH);
}

function isTodo(value: unknown): value is Todo {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<Todo>;
  return (
    typeof candidate.id === "number" &&
    Number.isInteger(candidate.id) &&
    candidate.id > 0 &&
    typeof candidate.text === "string" &&
    typeof candidate.done === "boolean"
  );
}

function isTodoDetails(value: unknown): value is TodoDetails {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<TodoDetails>;
  const validAction =
    candidate.action === "list" ||
    candidate.action === "add" ||
    candidate.action === "toggle" ||
    candidate.action === "clear";
  return (
    validAction &&
    Array.isArray(candidate.todos) &&
    candidate.todos.every((todo) => isTodo(todo)) &&
    typeof candidate.nextId === "number" &&
    Number.isInteger(candidate.nextId) &&
    candidate.nextId >= 1 &&
    (candidate.error === undefined || typeof candidate.error === "string")
  );
}

const TodoParams = Type.Object({
  action: StringEnum(["list", "add", "toggle", "clear"] as const),
  text: Type.Optional(Type.String({ description: "Todo text (for add)" })),
  id: Type.Optional(Type.Integer({ minimum: 1, description: "Todo ID (for toggle)" })),
});

/**
 * UI component for the /todos command
 */
class TodoListComponent {
  private todos: Todo[];
  private theme: Theme;
  private onClose: () => void;
  private cachedWidth?: number;
  private cachedLines?: string[];

  constructor(todos: Todo[], theme: Theme, onClose: () => void) {
    this.todos = todos;
    this.theme = theme;
    this.onClose = onClose;
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
      this.onClose();
    }
  }

  render(width: number): string[] {
    if (this.cachedLines && this.cachedWidth === width) {
      return this.cachedLines;
    }

    const lines: string[] = [];
    const th = this.theme;

    lines.push("");
    const title = th.fg("accent", " Todos ");
    const headerLine =
      th.fg("borderMuted", "─".repeat(3)) + title + th.fg("borderMuted", "─".repeat(Math.max(0, width - 10)));
    lines.push(truncateToWidth(headerLine, width));
    lines.push("");

    if (this.todos.length === 0) {
      lines.push(truncateToWidth(`  ${th.fg("dim", "No todos yet. Ask the agent to add some!")}`, width));
    } else {
      const done = this.todos.filter((t) => t.done).length;
      const total = this.todos.length;
      lines.push(truncateToWidth(`  ${th.fg("muted", `${done}/${total} completed`)}`, width));
      lines.push("");

      for (const todo of this.todos) {
        const check = todo.done ? th.fg("success", "✓") : th.fg("dim", "○");
        const id = th.fg("accent", `#${todo.id}`);
        const safeText = sanitizeTodoText(todo.text);
        const text = todo.done ? th.fg("dim", safeText) : th.fg("text", safeText);
        lines.push(truncateToWidth(`  ${check} ${id} ${text}`, width));
      }
    }

    lines.push("");
    lines.push(truncateToWidth(`  ${th.fg("dim", "Press Escape to close")}`, width));
    lines.push("");

    this.cachedWidth = width;
    this.cachedLines = lines;
    return lines;
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
}

export default function (pi: ExtensionAPI) {
  // In-memory state (reconstructed from session on load)
  let todos: Todo[] = [];
  let nextId = 1;

  /**
   * Reconstruct state from session entries.
   * Scans tool results for this tool and applies them in order.
   */
  const reconstructState = (ctx: ExtensionContext) => {
    todos = [];
    nextId = 1;

    const branchEntries = Array.from(ctx.sessionManager.getBranch());
    for (let i = branchEntries.length - 1; i >= 0; i--) {
      const entry = branchEntries[i];
      if (entry.type !== "message") continue;
      const msg = entry.message;
      if (msg.role !== "toolResult" || msg.toolName !== "todo") continue;

      const details = msg.details;
      if (isTodoDetails(details)) {
        todos = cloneTodos(details.todos);
        nextId = details.nextId;
        break;
      }
    }
  };

  // Reconstruct state on session events
  pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
  pi.on("session_switch", async (_event, ctx) => reconstructState(ctx));
  pi.on("session_fork", async (_event, ctx) => reconstructState(ctx));
  pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));

  // Register the todo tool for the LLM
  pi.registerTool({
    name: "todo",
    label: "Todo",
    description: "Manage a todo list. Actions: list, add (text), toggle (id), clear",
    parameters: TodoParams,

    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      switch (params.action) {
        case "list":
          return {
            content: [
              {
                type: "text",
                text: todos.length
                  ? todos.map((t) => `[${t.done ? "x" : " "}] #${t.id}: ${sanitizeTodoText(t.text)}`).join("\n")
                  : "No todos",
              },
            ],
            details: { action: "list", todos: cloneTodos(todos), nextId } as TodoDetails,
          };

        case "add": {
          const cleanedText = params.text ? sanitizeTodoText(params.text) : "";
          if (!cleanedText) {
            return {
              content: [{ type: "text", text: "Error: text required for add" }],
              details: { action: "add", todos: cloneTodos(todos), nextId, error: "text required" } as TodoDetails,
            };
          }
          if (todos.length >= MAX_TODOS) {
            return {
              content: [{ type: "text", text: `Error: maximum of ${MAX_TODOS} todos reached` }],
              details: {
                action: "add",
                todos: cloneTodos(todos),
                nextId,
                error: `max todos reached (${MAX_TODOS})`,
              } as TodoDetails,
            };
          }
          const newTodo: Todo = { id: nextId++, text: cleanedText, done: false };
          todos.push(newTodo);
          return {
            content: [{ type: "text", text: `Added todo #${newTodo.id}: ${newTodo.text}` }],
            details: { action: "add", todos: cloneTodos(todos), nextId } as TodoDetails,
          };
        }

        case "toggle": {
          if (params.id === undefined) {
            return {
              content: [{ type: "text", text: "Error: id required for toggle" }],
              details: { action: "toggle", todos: cloneTodos(todos), nextId, error: "id required" } as TodoDetails,
            };
          }
          const todo = todos.find((t) => t.id === params.id);
          if (!todo) {
            return {
              content: [{ type: "text", text: `Todo #${params.id} not found` }],
              details: {
                action: "toggle",
                todos: cloneTodos(todos),
                nextId,
                error: `#${params.id} not found`,
              } as TodoDetails,
            };
          }
          todo.done = !todo.done;
          return {
            content: [{ type: "text", text: `Todo #${todo.id} ${todo.done ? "completed" : "uncompleted"}` }],
            details: { action: "toggle", todos: cloneTodos(todos), nextId } as TodoDetails,
          };
        }

        case "clear": {
          const count = todos.length;
          todos = [];
          nextId = 1;
          return {
            content: [{ type: "text", text: `Cleared ${count} todos` }],
            details: { action: "clear", todos: [], nextId: 1 } as TodoDetails,
          };
        }

        default:
          return {
            content: [{ type: "text", text: `Unknown action: ${params.action}` }],
            details: {
              action: "list",
              todos: cloneTodos(todos),
              nextId,
              error: `unknown action: ${params.action}`,
            } as TodoDetails,
          };
      }
    },

    renderCall(args, theme) {
      let text = theme.fg("toolTitle", theme.bold("todo ")) + theme.fg("muted", args.action);
      if (args.text) text += ` ${theme.fg("dim", `"${sanitizeTodoText(args.text)}"`)}`;
      if (args.id !== undefined) text += ` ${theme.fg("accent", `#${args.id}`)}`;
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded }, theme) {
      if (!isTodoDetails(result.details)) {
        const text = result.content[0];
        return new Text(text?.type === "text" ? text.text : "", 0, 0);
      }
      const details = result.details;

      if (details.error) {
        return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);
      }

      const todoList = details.todos;

      switch (details.action) {
        case "list": {
          if (todoList.length === 0) {
            return new Text(theme.fg("dim", "No todos"), 0, 0);
          }
          let listText = theme.fg("muted", `${todoList.length} todo(s):`);
          const display = expanded ? todoList : todoList.slice(0, 5);
          for (const t of display) {
            const check = t.done ? theme.fg("success", "✓") : theme.fg("dim", "○");
            const safeText = sanitizeTodoText(t.text);
            const itemText = t.done ? theme.fg("dim", safeText) : theme.fg("muted", safeText);
            listText += `\n${check} ${theme.fg("accent", `#${t.id}`)} ${itemText}`;
          }
          if (!expanded && todoList.length > 5) {
            listText += `\n${theme.fg("dim", `... ${todoList.length - 5} more`)}`;
          }
          return new Text(listText, 0, 0);
        }

        case "add": {
          const added = todoList[todoList.length - 1];
          if (!added) {
            return new Text(theme.fg("success", "✓ Added todo"), 0, 0);
          }
          return new Text(
            theme.fg("success", "✓ Added ") +
              theme.fg("accent", `#${added.id}`) +
              " " +
              theme.fg("muted", sanitizeTodoText(added.text)),
            0,
            0,
          );
        }

        case "toggle": {
          const text = result.content[0];
          const msg = text?.type === "text" ? text.text : "";
          return new Text(theme.fg("success", "✓ ") + theme.fg("muted", msg), 0, 0);
        }

        case "clear":
          return new Text(theme.fg("success", "✓ ") + theme.fg("muted", "Cleared all todos"), 0, 0);
      }
    },
  });

  // Register the /todos command for users
  pi.registerCommand("todos", {
    description: "Show all todos on the current branch",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) {
        // Non-interactive mode has no command UI surface.
        return;
      }

      await ctx.ui.custom<void>((_tui, theme, _kb, done) => {
        return new TodoListComponent(todos, theme, () => done());
      });
    },
  });
}
