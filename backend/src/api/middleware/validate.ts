import type { NextFunction, Request, Response } from 'express';
import type { ZodTypeAny } from 'zod';
import { HttpError } from './errors.js';

/** zod-schema-driven request validation (single contract source, plan §13). */
export function validate(pairs: Array<{ schema: ZodTypeAny; source: 'body' | 'query' | 'params' }>) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      for (const { schema, source } of pairs) {
        if (source === 'query') (req as { query: unknown }).query = schema.parse(req.query);
        else if (source === 'params') Object.assign(req.params as object, schema.parse(req.params));
        else (req as { body: unknown }).body = schema.parse(req.body);
      }
      next();
    } catch (err) {
      next(err instanceof HttpError ? err : err);
    }
  };
}

export const asyncWrap =
  (fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>) =>
  (req: Request, res: Response, next: NextFunction): void => {
    fn(req, res, next).catch(next);
  };
