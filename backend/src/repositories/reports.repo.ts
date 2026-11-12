/** Community reports repo — pseudonymous, moderation-queued (plan §9.4, §15.4). */
import crypto from 'node:crypto';
import { getPool } from '../db/pool.js';
import type { CreateReport } from '../api/schemas/index.js';

export interface ReportDto {
  id: number;
  kind: string;
  severity: number;
  lat: number;
  lng: number;
  note: string | null;
  status: string;
  createdAt: string;
  /** coordinates fuzzed ±50 m at read time (plan §15.2) */
  confirmations?: number;
  denials?: number;
  /** the signed-in caller's vote, when they have one */
  myVote?: 'confirm' | 'deny' | null;
}

export async function createReport(
  input: CreateReport,
  userId: string | null,
  fingerprint: string | null,
): Promise<ReportDto & { duplicateHint: { nearbySameKind24h: number } }> {
  const pool = getPool();

  const dup = await pool.query(
    `SELECT count(*) AS n FROM safety_reports
     WHERE kind = $1 AND status <> 'rejected'
       AND ST_DWithin(
             geom::geography,
             ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography,
             100
           )
       AND created_at > now() - interval '24 hours'`,
    [input.kind, input.lat, input.lng],
  );
  const nearbySameKind24h = Number(dup.rows[0].n);

  const fpHash = fingerprint ? crypto.createHash('sha256').update(fingerprint).digest('hex').slice(0, 32) : null;
  const res = await pool.query(
    `INSERT INTO safety_reports (user_id, reporter_fp, kind, severity, note, status, trust_score, geom, expires_score_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, ST_SetSRID(ST_MakePoint($8, $9), 4326), now() + interval '60 days')
     RETURNING id, kind, severity, note, status, created_at,
               ST_Y(geom) AS lat, ST_X(geom) AS lng`,
    [userId, fpHash, input.kind, input.severity, input.note ?? null,
     'pending', userId ? 0.5 : 0.35, input.lng, input.lat],
  );
  const r = res.rows[0];
  return {
    id: r.id, kind: r.kind, severity: r.severity,
    lat: morphLat(r.lat), lng: morphLng(r.lng),
    note: r.note, status: r.status, createdAt: r.created_at,
    duplicateHint: { nearbySameKind24h },
  };
}

/** gentle coordinate fuzzing at read time (~50 m), never at storage (plan §15.2) */
function morphLat(lat: number): number { return Math.round((lat + (Math.sin(lat * 1e4) * 0.0002)) * 1e6) / 1e6; }
function morphLng(lng: number): number { return Math.round((lng + (Math.cos(lng * 1e4) * 0.0002)) * 1e6) / 1e6; }

export async function nearbyReports(
  lat: number, lng: number, radiusM: number, viewerId?: string | null,
): Promise<ReportDto[]> {
  const res = await getPool().query(
    `SELECT r.id, r.kind, r.severity, r.note, r.status, r.created_at,
            ST_Y(r.geom) AS lat, ST_X(r.geom) AS lng,
            COALESCE(v.confirmations, 0) AS confirmations,
            COALESCE(v.denials, 0) AS denials,
            mine.vote AS my_vote
     FROM safety_reports r
     LEFT JOIN (
       SELECT report_id,
              count(*) FILTER (WHERE vote = 1)::int AS confirmations,
              count(*) FILTER (WHERE vote = -1)::int AS denials
       FROM safety_report_votes GROUP BY report_id
     ) v ON v.report_id = r.id
     LEFT JOIN safety_report_votes mine
       ON mine.report_id = r.id AND mine.user_id = $4
     WHERE r.status = 'published'
       AND ST_DWithin(r.geom::geography, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography, $3)
     ORDER BY r.created_at DESC LIMIT 50`,
    [lat, lng, radiusM, viewerId ?? null],
  );
  return (res.rows as Array<Record<string, unknown>>).map((r) => ({
    id: Number(r.id),
    kind: String(r.kind),
    severity: Number(r.severity),
    lat: morphLat(Number(r.lat)),
    lng: morphLng(Number(r.lng)),
    note: r.note as string | null,
    status: String(r.status),
    createdAt: String(r.created_at),
    confirmations: Number(r.confirmations ?? 0),
    denials: Number(r.denials ?? 0),
    myVote: r.my_vote == null ? null : (Number(r.my_vote) === 1 ? 'confirm' : 'deny'),
  }));
}

export async function listPending(limit: number): Promise<Array<Record<string, unknown>>> {
  const res = await getPool().query(
    'SELECT id, kind, severity, note, status, created_at, ST_Y(geom) AS lat, ST_X(geom) AS lng FROM safety_reports WHERE status=\'pending\' ORDER BY created_at DESC LIMIT $1',
    [limit],
  );
  return res.rows;
}

export async function moderate(id: number, decision: 'published' | 'rejected', note?: string): Promise<void> {
  await getPool().query(
    "UPDATE safety_reports SET status = $2, note = COALESCE(NULLIF($3,''), note) WHERE id = $1",
    [id, decision, note ?? null],
  );
}

/**
 * Confirm/deny an existing report. Votes are a moderation signal, not a
 * popularity contest: they nudge `trust_score` within safe bounds and never
 * publish or reject a report on their own (plan §9.4 / §15.4).
 */
export async function vote(
  id: number,
  userId: string,
  up: boolean,
): Promise<{ confirmations: number; denials: number; trustScore: number; myVote: 'confirm' | 'deny' }> {
  const pool = getPool();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const report = await client.query(
      'SELECT id, user_id FROM safety_reports WHERE id = $1 AND status = \'published\'',
      [id],
    );
    if (report.rowCount === 0) {
      throw Object.assign(new Error('Report not found or not published'), { code: 'NOT_FOUND', status: 404 });
    }
    if (report.rows[0].user_id === userId) {
      throw Object.assign(new Error('You cannot vote on your own report'), { code: 'FORBIDDEN', status: 403 });
    }

    await client.query(
      `INSERT INTO safety_report_votes (report_id, user_id, vote)
       VALUES ($1, $2, $3)
       ON CONFLICT (report_id, user_id)
       DO UPDATE SET vote = EXCLUDED.vote, updated_at = now()`,
      [id, userId, up ? 1 : -1],
    );

    const counts = await client.query(
      `SELECT count(*) FILTER (WHERE vote = 1)::int AS confirmations,
              count(*) FILTER (WHERE vote = -1)::int AS denials
       FROM safety_report_votes WHERE report_id = $1`,
      [id],
    );
    const confirmations = Number(counts.rows[0]?.confirmations ?? 0);
    const denials = Number(counts.rows[0]?.denials ?? 0);
    // Bayesian-style nudge bounded to [0.05, 0.95]; denials weigh more.
    const raw = 0.5 + Math.min(0.4, confirmations * 0.05) - Math.min(0.45, denials * 0.08);
    const trustScore = Math.round(Math.max(0.05, Math.min(0.95, raw)) * 1000) / 1000;
    await client.query('UPDATE safety_reports SET trust_score = $2 WHERE id = $1', [id, trustScore]);
    await client.query('COMMIT');
    return { confirmations, denials, trustScore, myVote: up ? 'confirm' : 'deny' };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
