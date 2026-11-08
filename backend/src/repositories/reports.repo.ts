/** Community reports repo — pseudonymous, moderation-queued (plan §9.4, §15.4). */
import crypto from 'node:crypto';
import { getPool } from '../db/pool.js';
import { cellId } from '../lib/geo.js';
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
}

export async function createReport(
  input: CreateReport,
  userId: string | null,
  fingerprint: string | null,
): Promise<ReportDto & { duplicateHint: { nearbySameKind24h: number }> }> {
  const pool = getPool();
  const geo = [input.lng, input.lat];
  const cell = cellIdFrom([input.lat, input.lng]);

  const dup = await pool.query(
    `SELECT count(*) AS n FROM safety_reports
     WHERE kind = $1 AND status <> 'rejected'
       AND ST_DWithin(geom, ST_MakePoint($3, $2), 100)
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
     'pending', userId ? 0.5 : 0.35, geo[0], geo[1]],
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

function cellIdFrom(p: [number, number]): string {
  return cellId([p[0], p[1]], 100);
}

export async function nearbyReports(
  lat: number, lng: number, radiusM: number,
): Promise<ReportDto[]> {
  const res = await getPool().query(
    `SELECT id, kind, severity, note, status, created_at,
            ST_Y(geom) AS lat, ST_X(geom) AS lng
     FROM safety_reports
     WHERE status = 'published'
       AND ST_DWithin(geom, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography, $3)
     ORDER BY created_at DESC LIMIT 50`,
    [lat, lng, radiusM],
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

export async function vote(id: number, userId: string, up: boolean): Promise<void> {
  // votes adjust trust toward moderation; actual moderation queue for MVP uses admin ui
  void id; void userId; void up;
}
