import { DatabaseSync } from 'node:sqlite';
import { join } from 'node:path';
import { mkdirSync } from 'node:fs';
import type { Session, SessionEvent, IngestPayload, Summary } from './types.js';

const dataDir = process.env.XDG_DATA_HOME
  ? join(process.env.XDG_DATA_HOME, 'nix-agents')
  : join(process.env.HOME!, '.local', 'share', 'nix-agents');

mkdirSync(dataDir, { recursive: true });

const dbPath = process.env.NAX_DB_PATH ?? join(dataDir, 'observe.db');

export const db = new DatabaseSync(dbPath);

export function initDb(): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      profile TEXT NOT NULL DEFAULT 'default',
      project TEXT NOT NULL,
      started_at TEXT NOT NULL,
      ended_at TEXT,
      branch TEXT,
      last_commit TEXT,
      duration_sec REAL,
      input_tokens INTEGER,
      output_tokens INTEGER
    );
    CREATE TABLE IF NOT EXISTS events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT NOT NULL,
      occurred_at TEXT NOT NULL,
      event TEXT NOT NULL,
      data TEXT NOT NULL DEFAULT '{}'
    );
    CREATE INDEX IF NOT EXISTS events_session ON events(session_id);
    CREATE INDEX IF NOT EXISTS sessions_project ON sessions(project);
    CREATE INDEX IF NOT EXISTS sessions_started ON sessions(started_at DESC);
  `);
}

export function ingest(payload: IngestPayload): void {
  const now = new Date().toISOString();
  if (payload.event === 'session-start') {
    db.prepare(`
      INSERT OR IGNORE INTO sessions (id, profile, project, started_at)
      VALUES (?, ?, ?, ?)
    `).run(payload.sessionId, payload.profile ?? 'default', payload.project ?? '', payload.startedAt ?? now);
  } else if (payload.event === 'session-end') {
    db.prepare(`
      UPDATE sessions SET
        ended_at = ?,
        branch = ?,
        last_commit = ?,
        duration_sec = ?,
        input_tokens = ?,
        output_tokens = ?
      WHERE id = ?
    `).run(
      payload.endedAt ?? now,
      payload.branch ?? null,
      payload.lastCommit ?? null,
      payload.durationSec ?? null,
      payload.tokenUsage?.input ?? null,
      payload.tokenUsage?.output ?? null,
      payload.sessionId
    );
  } else {
    db.prepare(`
      INSERT INTO events (session_id, occurred_at, event, data)
      VALUES (?, ?, ?, ?)
    `).run(payload.sessionId, now, payload.event, JSON.stringify(payload.data ?? {}));
  }
}

export function querySessions(opts: {
  since?: string;
  project?: string;
  profile?: string;
  limit?: number;
}): Session[] {
  let sql = 'SELECT * FROM sessions WHERE 1=1';
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const params: any[] = [];
  if (opts.since) { sql += ' AND started_at >= ?'; params.push(opts.since); }
  if (opts.project) { sql += ' AND project LIKE ?'; params.push(`%${opts.project}%`); }
  if (opts.profile) { sql += ' AND profile = ?'; params.push(opts.profile); }
  sql += ' ORDER BY started_at DESC LIMIT ?';
  params.push(opts.limit ?? 50);
  return (db.prepare(sql).all(...params) as Record<string, unknown>[]).map(rowToSession);
}

export function querySession(id: string): { session: Session; events: SessionEvent[] } | null {
  const session = db.prepare('SELECT * FROM sessions WHERE id = ?').get(id) as Record<string, unknown> | undefined;
  if (!session) return null;
  const events = db.prepare('SELECT * FROM events WHERE session_id = ? ORDER BY occurred_at').all(id) as Record<string, unknown>[];
  return { session: rowToSession(session), events: events.map(rowToEvent) };
}

export function querySummary(): Summary {
  const total = (db.prepare('SELECT COUNT(*) as n FROM sessions').get() as { n: number }).n;
  const active = (db.prepare('SELECT COUNT(*) as n FROM sessions WHERE ended_at IS NULL').get() as { n: number }).n;
  const tokens = db.prepare('SELECT SUM(input_tokens) as i, SUM(output_tokens) as o FROM sessions').get() as { i: number | null; o: number | null };
  const projects = (db.prepare('SELECT DISTINCT project FROM sessions ORDER BY started_at DESC LIMIT 10').all() as { project: string }[]).map(r => r.project);
  return { totalSessions: total, activeSessions: active, totalInputTokens: tokens.i ?? 0, totalOutputTokens: tokens.o ?? 0, recentProjects: projects };
}

function rowToSession(r: Record<string, unknown>): Session {
  return {
    id: r.id as string,
    profile: r.profile as string,
    project: r.project as string,
    startedAt: r.started_at as string,
    endedAt: (r.ended_at as string | null) ?? null,
    branch: (r.branch as string | null) ?? null,
    lastCommit: (r.last_commit as string | null) ?? null,
    durationSec: (r.duration_sec as number | null) ?? null,
    inputTokens: (r.input_tokens as number | null) ?? null,
    outputTokens: (r.output_tokens as number | null) ?? null,
  };
}

function rowToEvent(r: Record<string, unknown>): SessionEvent {
  return {
    id: r.id as number,
    sessionId: r.session_id as string,
    occurredAt: r.occurred_at as string,
    event: r.event as string,
    data: JSON.parse(r.data as string) as Record<string, unknown>,
  };
}
