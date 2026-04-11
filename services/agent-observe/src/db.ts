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
  db.exec('PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;');
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
    CREATE TABLE IF NOT EXISTS skill_efficacy (
      skill_name    TEXT NOT NULL,
      skill_version TEXT NOT NULL DEFAULT 'unversioned',
      profile       TEXT NOT NULL DEFAULT 'default',
      sessions_n    INTEGER NOT NULL DEFAULT 0,
      commits_n     INTEGER NOT NULL DEFAULT 0,
      total_sec     REAL NOT NULL DEFAULT 0,
      last_updated  TEXT NOT NULL,
      PRIMARY KEY (skill_name, skill_version, profile)
    );
    CREATE TABLE IF NOT EXISTS agent_usage (
      agent_name   TEXT NOT NULL,
      profile      TEXT NOT NULL DEFAULT 'default',
      sessions_n   INTEGER NOT NULL DEFAULT 0,
      delegated_n  INTEGER NOT NULL DEFAULT 0,
      last_updated TEXT NOT NULL,
      PRIMARY KEY (agent_name, profile)
    );
    CREATE INDEX IF NOT EXISTS events_session ON events(session_id);
    CREATE INDEX IF NOT EXISTS events_event ON events(event);
    CREATE INDEX IF NOT EXISTS sessions_project ON sessions(project);
    CREATE INDEX IF NOT EXISTS sessions_started ON sessions(started_at DESC);
  `);
  // Migrate: add skill_versions column if it doesn't exist yet
  try {
    db.exec('ALTER TABLE sessions ADD COLUMN skill_versions TEXT');
  } catch (err) {
    // Only suppress "duplicate column" — rethrow anything else
    if (!(err instanceof Error) || !err.message.includes('duplicate column')) throw err;
  }
  // Migrate: add tier metadata columns
  const tierMigrations: string[] = [
    'ALTER TABLE sessions ADD COLUMN tier TEXT',
    'ALTER TABLE sessions ADD COLUMN parent_agent TEXT',
    'ALTER TABLE sessions ADD COLUMN delegation_depth INTEGER',
  ];
  for (const sql of tierMigrations) {
    try {
      db.exec(sql);
    } catch (err) {
      if (!(err instanceof Error) || !err.message.includes('duplicate column')) throw err;
    }
  }
}

export function ingest(payload: IngestPayload): void {
  const now = new Date().toISOString();
  if (payload.event === 'session-start') {
    db.prepare(`
      INSERT OR IGNORE INTO sessions (id, profile, project, started_at, skill_versions, tier, parent_agent, delegation_depth)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      payload.sessionId,
      payload.profile ?? 'default',
      payload.project ?? '',
      payload.startedAt ?? now,
      payload.skillVersions ? JSON.stringify(payload.skillVersions) : null,
      payload.tier ?? null,
      payload.parentAgent ?? null,
      payload.delegationDepth ?? null
    );
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

export function recomputeEfficacy(): void {
  const now = new Date().toISOString();

  db.exec('BEGIN');
  try {
    // Rebuild skill_efficacy
    db.exec('DELETE FROM skill_efficacy');

    const sessions = db.prepare(
      "SELECT id, profile, duration_sec, skill_versions FROM sessions WHERE skill_versions IS NOT NULL"
    ).all() as { id: string; profile: string; duration_sec: number | null; skill_versions: string }[];

    // Count commits per session
    const commitCounts = new Map<string, number>();
    const commitRows = db.prepare(
      "SELECT session_id, COUNT(*) as n FROM events WHERE event = 'commit' GROUP BY session_id"
    ).all() as { session_id: string; n: number }[];
    for (const row of commitRows) {
      commitCounts.set(row.session_id, row.n);
    }

    // Aggregate per (skill_name, skill_version, profile)
    type EfficacyKey = [skillName: string, skillVersion: string, profile: string];
    const efficacy = new Map<string, { key: EfficacyKey; sessions_n: number; commits_n: number; total_sec: number }>();
    for (const session of sessions) {
      let versions: Record<string, string>;
      try {
        versions = JSON.parse(session.skill_versions) as Record<string, string>;
      } catch {
        continue;
      }
      const commits = commitCounts.get(session.id) ?? 0;
      const dur = session.duration_sec ?? 0;
      for (const [skillName, skillVersion] of Object.entries(versions)) {
        const key: EfficacyKey = [skillName, skillVersion ?? 'unversioned', session.profile];
        const mapKey = JSON.stringify(key);
        const existing = efficacy.get(mapKey) ?? { key, sessions_n: 0, commits_n: 0, total_sec: 0 };
        existing.sessions_n++;
        existing.commits_n += commits;
        existing.total_sec += dur;
        efficacy.set(mapKey, existing);
      }
    }

    const insertEfficacy = db.prepare(`
      INSERT INTO skill_efficacy (skill_name, skill_version, profile, sessions_n, commits_n, total_sec, last_updated)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);
    for (const { key, ...stats } of efficacy.values()) {
      insertEfficacy.run(key[0], key[1], key[2], stats.sessions_n, stats.commits_n, stats.total_sec, now);
    }

    // Rebuild agent_usage from delegation events
    db.exec('DELETE FROM agent_usage');

    const delegationRows = db.prepare(
      "SELECT e.data, s.profile FROM events e JOIN sessions s ON e.session_id = s.id WHERE e.event = 'delegation'"
    ).all() as { data: string; profile: string }[];

    type AgentKey = [agentName: string, profile: string];
    const agentUsage = new Map<string, { key: AgentKey; delegated_n: number }>();
    for (const row of delegationRows) {
      let data: Record<string, unknown>;
      try {
        data = JSON.parse(row.data) as Record<string, unknown>;
      } catch {
        continue;
      }
      const toAgent = data['to_agent'] as string | undefined;
      if (!toAgent) continue;
      const key: AgentKey = [toAgent, row.profile];
      const mapKey = JSON.stringify(key);
      const existing = agentUsage.get(mapKey) ?? { key, delegated_n: 0 };
      existing.delegated_n++;
      agentUsage.set(mapKey, existing);
    }

    // sessions_n per profile for ratio computation
    const sessionsByProfile = new Map<string, number>();
    const profileRows = db.prepare(
      "SELECT profile, COUNT(*) as n FROM sessions GROUP BY profile"
    ).all() as { profile: string; n: number }[];
    for (const row of profileRows) {
      sessionsByProfile.set(row.profile, row.n);
    }

    const insertAgent = db.prepare(`
      INSERT INTO agent_usage (agent_name, profile, sessions_n, delegated_n, last_updated)
      VALUES (?, ?, ?, ?, ?)
    `);
    for (const { key, ...stats } of agentUsage.values()) {
      const sessionsN = sessionsByProfile.get(key[1]) ?? 0;
      insertAgent.run(key[0], key[1], sessionsN, stats.delegated_n, now);
    }

    db.exec('COMMIT');
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
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
    skillVersions: r.skill_versions
      ? (JSON.parse(r.skill_versions as string) as Record<string, string>)
      : undefined,
    tier: (r.tier as string | null) ?? null,
    parentAgent: (r.parent_agent as string | null) ?? null,
    delegationDepth: (r.delegation_depth as number | null) ?? null,
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
