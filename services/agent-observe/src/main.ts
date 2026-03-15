import { initDb, recomputeEfficacy, querySessions, querySession, querySummary, ingest, db } from './db.js';
import { startServer } from './server.js';
import { startMcp } from './mcp.js';
import { queryInsights } from './insights.js';
import { readFileSync } from 'node:fs';

initDb();

const [,, command, ...args] = process.argv;

function parseFlags(args: string[]): Record<string, string> {
  const flags: Record<string, string> = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      flags[args[i].slice(2)] = args[i + 1] ?? 'true';
      i++;
    }
  }
  return flags;
}

switch (command) {
  case 'serve': {
    const flags = parseFlags(args);
    startServer(Number(flags.port ?? '7734'));
    break;
  }
  case 'mcp': {
    startMcp().catch(console.error);
    break;
  }
  case 'sessions': {
    const flags = parseFlags(args);
    const sessions = querySessions({
      since: flags.since,
      project: flags.project,
      profile: flags.profile,
      limit: flags.limit ? Number(flags.limit) : 20,
    });
    console.log(JSON.stringify(sessions, null, 2));
    break;
  }
  case 'summary': {
    console.log(JSON.stringify(querySummary(), null, 2));
    break;
  }
  case 'ingest': {
    const file = args[0];
    if (!file) { console.error('Usage: agent-observe ingest <session.json>'); process.exit(1); }
    const session = JSON.parse(readFileSync(file, 'utf8')) as Record<string, unknown>;
    ingest({ sessionId: session.sessionId as string, event: 'session-start', profile: session.profile as string, project: session.project as string, startedAt: session.startedAt as string, skillVersions: session.skillVersions as Record<string, string> | undefined });
    if (session.endedAt) {
      ingest({ sessionId: session.sessionId as string, event: 'session-end', endedAt: session.endedAt as string, branch: session.branch as string, lastCommit: session.lastCommit as string, durationSec: session.durationSec as number, tokenUsage: session.tokenUsage as { input: number; output: number } });
    }
    console.log('Ingested:', session.sessionId);
    break;
  }
  case 'optimize': {
    const flags = parseFlags(args);
    const minSessions = flags['min-sessions'] ? Number(flags['min-sessions']) : 10;
    const jsonOutput = 'json' in flags;
    recomputeEfficacy();
    const insights = queryInsights(db, { minSessions });
    if (jsonOutput) {
      console.log(JSON.stringify(insights, null, 2));
    } else if (insights.length === 0) {
      console.log('No optimization insights available yet. More session data is needed (minimum ' + minSessions + ' sessions per skill version).');
    } else {
      for (const insight of insights) {
        console.log(`[${insight.confidence.toUpperCase()}] ${insight.type}: ${insight.subject}`);
        console.log(`  Finding: ${insight.detail}`);
        console.log(`  Recommendation: ${insight.recommendation}`);
        console.log(`  Based on ${insight.dataPoints} sessions`);
        console.log();
      }
    }
    break;
  }
  default: {
    console.error(`Usage: agent-observe <serve|mcp|sessions|summary|ingest|optimize>`);
    console.error('Commands:');
    console.error('  serve [--port 7734]                    Start HTTP server');
    console.error('  mcp                                    Start MCP server (stdio)');
    console.error('  sessions [--since DATE] [--project PATH] [--limit N]');
    console.error('  summary                                Show aggregate stats');
    console.error('  ingest <session.json>                  Import a session file');
    console.error('  optimize [--min-sessions N] [--json]   Analyze skill efficacy and suggest improvements');
    process.exit(1);
  }
}
