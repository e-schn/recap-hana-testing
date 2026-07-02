import { defineConfig } from 'vitest/config';

/**
 * Vitest config for CAP tests.
 * - `globals: true` lets us use describe/it/expect without importing them,
 *   matching the classic cds.test / Jest style.
 * - HANA round-trips are slower than SQLite, so timeouts are generous.
 * - Tests run sequentially (single fork) to avoid concurrent access to the
 *   shared HANA test container.
 */
export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    testTimeout: 120_000,
    hookTimeout: 120_000,
    pool: 'forks',
    poolOptions: {
      forks: { singleFork: true },
    },
    include: ['test/**/*.test.ts'],
  },
});
