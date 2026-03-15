export interface Session {
  id: string;
  profile: string;
  project: string;
  startedAt: string;
  endedAt: string | null;
  branch: string | null;
  lastCommit: string | null;
  durationSec: number | null;
  inputTokens: number | null;
  outputTokens: number | null;
}

export interface SessionEvent {
  id: number;
  sessionId: string;
  occurredAt: string;
  event: string;
  data: Record<string, unknown>;
}

export interface IngestPayload {
  sessionId: string;
  event: string;
  data?: Record<string, unknown>;
  profile?: string;
  project?: string;
  startedAt?: string;
  endedAt?: string;
  branch?: string;
  lastCommit?: string;
  durationSec?: number;
  tokenUsage?: { input: number; output: number };
}

export interface Summary {
  totalSessions: number;
  activeSessions: number;
  totalInputTokens: number;
  totalOutputTokens: number;
  recentProjects: string[];
}
