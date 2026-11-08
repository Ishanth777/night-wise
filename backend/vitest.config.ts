import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/*.spec.ts'],
    environment: 'node',
    // Integration tests (DB/Redis/Valhalla required) are skipped unless RUN_INTEGRATION=1
    exclude: ['node_modules/**'],
    testTimeout: 30_000,
  },
});
