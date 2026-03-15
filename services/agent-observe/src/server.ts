import express from 'express';
import { ingest, querySessions, querySession, querySummary } from './db.js';
import type { IngestPayload } from './types.js';

export function startServer(port: number): void {
  const app = express();
  app.use(express.json());

  app.post('/events', (req, res) => {
    try {
      ingest(req.body as IngestPayload);
      res.json({ ok: true });
    } catch (err) {
      console.error('[observe] ingest error:', err);
      res.status(400).json({ error: String(err) });
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
