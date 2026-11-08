import pino from 'pino';

const REDACT = [
  // plan §15.2: never log raw coordinates or credentials
  'req.headers.authorization', 'password', 'token', 'req.body.origin', 'req.body.destination',
];

const log = pino(
  {
    level: process.env.LOG_LEVEL ?? 'info',
    redact: { paths: REDACT, censor: '[redacted]' },
    base: { service: 'nightwise-api' },
  },
);

export default log;
