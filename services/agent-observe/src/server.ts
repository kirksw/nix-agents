import express from 'express';
import { z } from 'zod';
import { ingest, querySessions, querySession, querySummary } from './db.js';

const IngestSchema = z.object({
  sessionId: z.string().min(1),
  event: z.string().min(1),
  data: z.record(z.unknown()).optional(),
  profile: z.string().optional(),
  project: z.string().optional(),
  startedAt: z.string().optional(),
  endedAt: z.string().optional(),
  branch: z.string().optional(),
  lastCommit: z.string().optional(),
  durationSec: z.number().optional(),
  tokenUsage: z.object({ input: z.number(), output: z.number() }).optional(),
});

export function startServer(port: number): void {
  const app = express();
  app.use(express.json());

  app.post('/events', (req, res) => {
    const parsed = IngestSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    try {
      ingest(parsed.data);
      res.json({ ok: true });
    } catch (err) {
      console.error('[observe] ingest error:', err);
      res.status(500).json({ error: String(err) });
    }
  });

  app.get('/sessions', (req, res) => {
    const { since, project, profile, limit } = req.query as Record<string, string>;
    res.json(querySessions({ since, project, profile, limit: limit ? Number(limit) : undefined }));
  });

  app.get('/sessions/:id', (req, res) => {
    const result = querySession(req.params.id);
    if (!result) { res.status(404).json({ error: 'not found' }); return; }
    res.json(result);
  });

  app.get('/summary', (_req, res) => {
    res.json(querySummary());
  });

  app.listen(port, '127.0.0.1', () => {
    console.log(`[observe] HTTP server listening on 127.0.0.1:${port}`);
  });
}
