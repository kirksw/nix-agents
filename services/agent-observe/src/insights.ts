import type { DatabaseSync } from 'node:sqlite';

export interface InsightRow {
  type: 'skill-regression' | 'low-usage-agent';
  subject: string;
  detail: string;
  recommendation: string;
  confidence: 'low' | 'medium' | 'high';
  dataPoints: number;
}

export interface InsightsOptions {
  minSessions?: number;
}

export function queryInsights(db: DatabaseSync, opts: InsightsOptions = {}): InsightRow[] {
  const minSessions = opts.minSessions ?? 10;
  const insights: InsightRow[] = [];

  // 1. Skill regression: compare commit rates across versions
  const efficacyRows = db.prepare(
    'SELECT skill_name, skill_version, profile, sessions_n, commits_n FROM skill_efficacy ORDER BY skill_name, skill_version'
  ).all() as { skill_name: string; skill_version: string | null; profile: string; sessions_n: number; commits_n: number }[];

  // Group by (skill_name, profile) — use JSON tuple keys to avoid delimiter collisions
  const bySkillProfile = new Map<string, typeof efficacyRows>();
  for (const row of efficacyRows) {
    const mapKey = JSON.stringify([row.skill_name, row.profile]);
    const existing = bySkillProfile.get(mapKey) ?? [];
    existing.push(row);
    bySkillProfile.set(mapKey, existing);
  }

  for (const [mapKey, rows] of bySkillProfile) {
    // Need at least 2 versions each with enough sessions
    const qualified = rows.filter(r => r.sessions_n >= minSessions);
    if (qualified.length < 2) continue;

    // Sort versions numerically (semver-aware: compare each dot-separated segment as integer)
    qualified.sort((a, b) => {
      const aParts = (a.skill_version ?? '0').split('.').map(Number);
      const bParts = (b.skill_version ?? '0').split('.').map(Number);
      for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
        const diff = (aParts[i] ?? 0) - (bParts[i] ?? 0);
        if (diff !== 0) return diff;
      }
      return 0;
    });
    const prev = qualified[qualified.length - 2];
    const latest = qualified[qualified.length - 1];

    const prevRate = prev.sessions_n > 0 ? prev.commits_n / prev.sessions_n : 0;
    const latestRate = latest.sessions_n > 0 ? latest.commits_n / latest.sessions_n : 0;

    // Flag if latest is >20% lower than previous
    if (prevRate > 0 && latestRate < prevRate * 0.8) {
      const pctDrop = Math.round((1 - latestRate / prevRate) * 100);
      const [skillName, profile] = JSON.parse(mapKey) as [string, string];
      insights.push({
        type: 'skill-regression',
        subject: skillName,
        detail: `v${latest.skill_version ?? 'unversioned'} has ${pctDrop}% lower commit rate than v${prev.skill_version ?? 'unversioned'} (${latestRate.toFixed(2)} vs ${prevRate.toFixed(2)} commits/session) in profile "${profile}"`,
        recommendation: `Consider reverting ${skillName} to v${prev.skill_version ?? 'unversioned'} or reviewing recent prompt changes`,
        confidence: latest.sessions_n >= minSessions * 2 ? 'high' : 'medium',
        dataPoints: latest.sessions_n,
      });
    }
  }

  // 2. Low-usage agents: delegated_n / sessions_n < 2%
  const agentRows = db.prepare(
    'SELECT agent_name, profile, sessions_n, delegated_n FROM agent_usage WHERE sessions_n > 0'
  ).all() as { agent_name: string; profile: string; sessions_n: number; delegated_n: number }[];

  for (const row of agentRows) {
    if (row.sessions_n < minSessions) continue;
    const ratio = row.delegated_n / row.sessions_n;
    if (ratio < 0.02) {
      const pct = (ratio * 100).toFixed(1);
      insights.push({
        type: 'low-usage-agent',
        subject: row.agent_name,
        detail: `${row.agent_name} was delegated to in only ${pct}% of sessions (${row.delegated_n}/${row.sessions_n}) in profile "${row.profile}"`,
        recommendation: `Consider removing or consolidating ${row.agent_name} if it is no longer providing value`,
        confidence: row.sessions_n >= minSessions * 3 ? 'high' : 'medium',
        dataPoints: row.sessions_n,
      });
    }
  }

  return insights;
}
