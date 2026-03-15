import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { querySessions, querySession, querySummary, recomputeEfficacy, db } from './db.js';
import { queryInsights } from './insights.js';

export async function startMcp(): Promise<void> {
  const server = new Server({ name: 'agent-observe', version: '0.1.0' }, { capabilities: { tools: {} } });

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
      {
        name: 'observe_sessions',
        description: 'List recent AI coding sessions. Optionally filter by date, project path, or profile.',
        inputSchema: {
          type: 'object',
          properties: {
            since: { type: 'string', description: 'ISO date string, e.g. 2026-03-01' },
            project: { type: 'string', description: 'Partial project path to filter by' },
            profile: { type: 'string' },
            limit: { type: 'number', default: 20 },
          },
        },
      },
      {
        name: 'observe_summary',
        description: 'Get aggregate stats: total sessions, token usage, recent projects.',
        inputSchema: { type: 'object', properties: {} },
      },
      {
        name: 'observe_session',
        description: 'Get full details for a session including all events.',
        inputSchema: {
          type: 'object',
          required: ['id'],
          properties: { id: { type: 'string' } },
        },
      },
      {
        name: 'observe_insights',
        description: 'Analyze session history to find underperforming skills, low-usage agents, and model tier optimization opportunities.',
        inputSchema: {
          type: 'object',
          properties: {
            minSessions: { type: 'number', description: 'Minimum sessions per skill version to be considered (default: 10)' },
          },
        },
      },
    ],
  }));

  server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const args = (req.params.arguments ?? {}) as Record<string, unknown>;
    if (req.params.name === 'observe_sessions') {
      const sessions = querySessions({
        since: args.since as string | undefined,
        project: args.project as string | undefined,
        profile: args.profile as string | undefined,
        limit: args.limit as number | undefined,
      });
      return { content: [{ type: 'text', text: JSON.stringify(sessions, null, 2) }] };
    }
    if (req.params.name === 'observe_summary') {
      return { content: [{ type: 'text', text: JSON.stringify(querySummary(), null, 2) }] };
    }
    if (req.params.name === 'observe_session') {
      const result = querySession(args.id as string);
      if (\!result) {
        return { content: [{ type: 'text', text: `Session not found: ${args.id as string}` }], isError: true };
      }
      return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
    }
    if (req.params.name === 'observe_insights') {
      recomputeEfficacy();
      const insights = queryInsights(db, { minSessions: args.minSessions as number | undefined });
      return { content: [{ type: 'text', text: JSON.stringify(insights, null, 2) }] };
    }
    throw new Error(`Unknown tool: ${req.params.name}`);
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);
}
