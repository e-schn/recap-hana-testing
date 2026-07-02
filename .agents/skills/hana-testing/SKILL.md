---
name: hana-testing
description: Use when adding or changing any CAP (SAP Cloud Application Programming Model) entity, service, custom handler, or native HANA artifact (.hdbview, calculation view, .hdbtable, function, procedure) or HANA-specific SQL — ensures new code ships with automated tests that run against a real SAP HANA Cloud instance via vitest, not only in-memory SQLite.
---

# Testing CAP Applications Against SAP HANA Cloud

When you add or modify CAP code, you MUST also provide/extend automated tests that
can run against **real SAP HANA Cloud**, using **vitest** with `@cap-js/cds-test`.
In-memory SQLite is fine for fast unit feedback, but it does NOT validate
HANA-specific behavior. Always add a HANA-backed integration test for anything that
depends on the database.

## When HANA-backed tests are REQUIRED (not just SQLite)

Add a HANA test whenever the change touches any of:

- **Native HANA artifacts**: `.hdbview`, `.hdbcalculationview`, `.hdbtable`,
  `.hdbfunction`, `.hdbprocedure`, `.hdbsynonym`.
- **HANA-specific SQL**: functions/expressions that only exist or only behave
  correctly on HANA (regex functions, aggregations, window functions, spatial, JSON).
- **Entities annotated `@cds.persistence.exists`** (they map to objects that only
  exist in the HDI container).
- **HDI deployment artifacts** or anything relying on production-like persistence.

For pure application logic with no DB specifics, a SQLite test is acceptable — but
prefer to also cover it on HANA when it reads/writes persisted data.

## The Rule

Every new persisted entity, service projection, or native artifact gets:

1. A **vitest** spec under `test/` using `cds.test(...)`.
2. Assertions on real query results (not mocks).
3. It must pass under `npm test` (which runs against bound HANA), not only
   `npm run test:local` (SQLite).

## Project Setup (once)

`package.json` — dependencies and scripts:

```jsonc
{
  "dependencies": { "@cap-js/hana": "^2", "@sap/cds": "^9" },
  "devDependencies": {
    "@cap-js/cds-test": ">=0.4.1",
    "@cap-js/sqlite": "^2",
    "vitest": "^3"
  },
  "scripts": {
    "test:local": "NODE_ENV=development CDS_ENV=development cds_requires_db_credentials_url=:memory: vitest run",
    "test": "cds bind --exec --profile test vitest run"
  },
  "cds": {
    "requires": {
      "[development]": { "db": "sqlite" },
      "[test]": { "db": "hana", "auth": { "kind": "dummy" } }
    }
  }
}
```

`vitest.config.ts` — HANA needs generous timeouts and serial execution:

```ts
import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    testTimeout: 120_000,
    hookTimeout: 120_000,
    pool: 'forks',
    poolOptions: { forks: { singleFork: true } },
    include: ['test/**/*.test.ts'],
  },
});
```

Notes:
- vitest sets `NODE_ENV=test`, so CAP activates the `[test]` profile (→ HANA)
  automatically. `test:local` forces `NODE_ENV=development` + in-memory SQLite so
  `cds.test` auto-deploys a fresh DB.
- `cds.test()` returns `{ GET, POST, PUT, DELETE, expect, axios, ... }` and works with
  any runner; with `globals: true` you get `describe/it` without imports.

## Writing a Test

```ts
import cds from '@sap/cds';
const { GET, expect } = cds.test(__dirname + '/..');

describe('WorldCupService', () => {
  it('serves Teams', async () => {
    const { data } = await GET`/odata/v4/worldcup/Teams`;
    expect(data.value).to.containSubset([{ ID: 1 }]);
  });
});
```

For a native HANA SQL view (or HANA-only function) exposed through a CDS entity,
assert the result — this only succeeds on HANA:

```ts
it('ranks teams via the native HANA view', async () => {
  const { data } = await GET`/odata/v4/worldcup/TeamStandings`;
  expect(data.value).to.containSubset([{ TEAM: 'Argentina', STAGE: 'Group', GOALS: 7, RANK_IN_STAGE: 1 }]);
});

it('uses the HANA dayname() function', async () => {
  const { data } = await GET`/odata/v4/worldcup/MatchdaysByWeekday`;
  expect(data.value).to.containSubset([{ ID: 1, weekday: 'Friday' }]);
});
```

## Consuming a Native HANA Artifact from CDS

1. Put the artifact under `db/src/` (e.g. `db/src/WORLDCUP_TEAM_STANDINGS.hdbview`)
   and ensure `db/src/.hdiconfig` maps `hdbview` to `com.sap.hana.di.view`.
2. Expose it via a CDS entity whose **SQL name matches the view id** and mark it
   `@cds.persistence.exists` (no namespace, so the name is not prefixed):

   ```cds
   @cds.persistence.exists
   entity WORLDCUP_TEAM_STANDINGS {
     key TEAM          : String;
     key STAGE         : String;
         GOALS         : Integer;
         RANK_IN_STAGE : Integer;
   }
   ```
3. Project it in a service. It resolves on HANA and errors on SQLite — exactly what
   the HANA test proves. The same applies to HANA-only SQL functions used directly
   in a CDS projection (e.g. `dayname(matchDate) as weekday`): CAP passes them through
   to SQL, so they run on HANA but raise `no such function` on SQLite.

## Running Against Real HANA (the loop new code must pass)

```bash
# 1. Cloud Foundry: log in and target the space
cf login                       # or: cf login --sso
cf target -o <org> -s <space>

# 2. Provision a dedicated HANA test instance (HDI)
cf create-service hana hdi-shared <cap-test-instance>
cf services                    # wait until "create succeeded"

# 3. Bind the instance to the test profile (writes .cdsrc-private.json — gitignored)
cds bind --to <cap-test-instance> --for test

# 4. Deploy the data model into the test container
cds deploy --to hana:<cap-test-instance> --profile test --auto-undeploy

# 5. Run the tests with the bound credentials
cds bind --exec --profile test vitest run
# TypeScript projects:
CDS_TYPESCRIPT='true' cds bind --exec --profile test vitest run
```

Inspect persisted data when an assertion fails:

```bash
cds bind --exec --profile test cds repl -- --run .
# then, in the REPL:
await SELECT.from('WorldCupService.Teams')
await SELECT.from('WORLDCUP_TEAM_STANDINGS')
```

## Best Practices

- Keep a dedicated HANA instance for tests only; never test against production data.
- Keep test data deterministic and minimal; do not rely on execution order.
- Never hardcode credentials — always use `cds bind`. Never commit
  `.cdsrc-private.json`.
- Treat HANA tests as an integration gate; keep fast SQLite unit tests too.
- In CI: `cf create-service` → `cds bind --for test` → `cds deploy ... --profile test`
  → `cds bind --exec --profile test vitest run`, then clean up the instance.

## Definition of Done for New CAP Code

- [ ] New/changed entity, service, handler, or native artifact has a vitest spec.
- [ ] The spec passes under `npm test` (bound HANA), not only `npm run test:local`.
- [ ] Native-HANA behavior (native views, HANA-only functions/SQL) is asserted on real HANA.
- [ ] No credentials committed; bindings created via `cds bind`.
