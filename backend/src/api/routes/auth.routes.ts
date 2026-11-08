import { Router } from 'express';
import { validate, asyncWrap } from '../middleware/validate.js';
import { attachDeviceHash } from '../middleware/auth.js';
import { RegisterSchema, LoginSchema } from '../schemas/index.js';
import { register, login, refresh, logout } from '../../services/auth.service.js';

export const authRoutes = Router();
authRoutes.use(attachDeviceHash);

authRoutes.post('/register', validate([{ schema: RegisterSchema, source: 'body' }]),
  asyncWrap(async (req, res) => {
    const { email, password, displayName } = (req as { body: { email: string; password: string; displayName?: string } }).body;
    const session = await register(email, password, displayName ?? null,
      (res.locals as { deviceHash?: string }).deviceHash ?? null);
    res.status(201).json({ data: session });
  }));

authRoutes.post('/login', validate([{ schema: LoginSchema, source: 'body' }]),
  asyncWrap(async (req, res) => {
    const { email, password } = req.body as { email: string; password: string };
    const session = await login(email, password, (res.locals as { deviceHash?: string }).deviceHash ?? null);
    res.json({ data: session });
  }));

authRoutes.post('/refresh',
  asyncWrap(async (req, res) => {
    const token = (req.body as { refreshToken?: string })?.refreshToken
      ?? (req.headers.cookie as string | undefined)?.match(/nw_refresh=([\w-]+)/)?.[1] ?? '';
    const session = await refresh(token, (res.locals as { deviceHash?: string }).deviceHash ?? null);
    res.json({ data: session });
  }));

authRoutes.post('/logout',
  asyncWrap(async (req, res) => {
    const token = (req.body as { refreshToken?: string })?.refreshToken ?? '';
    await logout(token);
    res.status(204).end();
  }));
