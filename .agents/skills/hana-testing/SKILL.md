---
name: hana-testing
description: Use when adding or changing any CAP (SAP Cloud Application Programming Model) entity, service, custom handler, or native HANA artifact (.hdbview, calculation view, .hdbtable, function, procedure) or HANA-specific SQL — ensures new code ships with automated tests that run against a real SAP HANA Cloud instance via vitest.
---

# Testing CAP Applications Against SAP HANA Cloud

When you add or modify CAP code, you MUST also provide/extend automated tests that
can run against **real SAP HANA Cloud**, using **vitest** with `@cap-js/cds-test`.
Always add a HANA-backed integration test for anything that
depends on the database.

## When HANA-backed tests are REQUIRED (not just SQLite)

Add a HANA test whenever the change touches any of:

- **Native HANA artifacts**: `.hdbview`, `.hdbcalculationview`, `.hdbtable`,
  `.hdbfunction`, `.hdbprocedure`, `.hdbsynonym`, in case the artifact is used in a service projection or custom handler.
- **HANA-specific SQL & behavior**: functions/expressions that only exist or behave
  differently on HANA — regex functions, aggregations, window functions, spatial,
  JSON, and date-name functions like `dayname()`/`monthname()`. Also **fuzzy search**:
  the OOTB `$search` query option is a plain substring `LIKE` on SQLite but fuzzy
  `CONTAINS(... FUZZY)` on HANA (tune with `@Search.fuzzinessThreshold`).
- **Entities annotated `@cds.persistence.exists`** (they map to objects that only
  exist in the HDI container).
- **HDI deployment artifacts** or anything relying on production-like persistence.

For pure application logic with no DB specifics, a SQLite test is acceptable — but
prefer to also cover it on HANA when it reads/writes persisted data.

## The Rule

Every new persisted entity, service projection, or native artifact gets:

1. A **vitest** spec under `test/` using `cds.test(...)`.
2. Assertions on real query results (not mocks).
3. It must pass under `npm run test:hana` (which runs against bound HANA), not only
   `npm run test:sqlite` (in-memory SQLite).

## Project Setup (already configured in this repo)

This project is **already set up** to test against SAP HANA Cloud — you do NOT need to
re-create dependencies, scripts, profiles, or a HANA instance. Just add your specs
under `test/` and run the existing scripts. The current configuration, for reference:

`package.json` — a **TypeScript** CAP project (cds 10 / hana 3) with dedicated scripts:

```jsonc
{
  "dependencies": {
    "@cap-js/hana": "^3",
    "@sap/cds": "^10",
    "@sap/xssec": "^4"
  },
  "devDependencies": {
    "@cap-js/cds-test": "^1.0.1",
    "@cap-js/cds-typer": ">=0.4",
    "@cap-js/cds-types": "^0.18.0",
    "@cap-js/sqlite": "^3",
    "@sap/cds-dk": "^10",
    "tsx": "^4",
    "typescript": "^5",
    "vitest": "^4"
  },
  "scripts": {
    // fast inner loop on in-memory SQLite (no HANA binding required)
    "test:sqlite": "NODE_ENV=development CDS_TYPESCRIPT=true cds_requires_db_credentials_url=:memory: vitest --coverage --ui --open=false",
    // integration run against the bound HANA test container
    "test:hana": "CDS_TYPESCRIPT=true cds bind --exec --profile hana vitest -- --coverage",
    // (re)deploy the data model into the bound HANA HDI container
    "deploy:hana": "cds deploy --to hana:recap-test-hana-db --for hana --auto-undeploy",
    // REPL bound to HANA for inspecting persisted data
    "repl:hana": "cds bind --exec --profile hana cds repl -- --run ."
  },
  "cds": {
    "requires": {
      "[development]": { "db": "sql" },
      "[hana]": { "db": "hana", "auth": { "kind": "dummy" } },
      "[production]": { "db": "hana", "auth": "xsuaa" }
    },
    "hana": { "deploy-format": "hdbtable" }
  }
}
```

`vitest.config.ts` — HANA round-trips are slow, so timeouts are generous and specs run
serially (single fork) against the shared HANA container:

```ts
import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: {
    environment: 'node',
    testTimeout: 120_000,
    pool: 'forks',
    execArgv: ['--import', 'tsx'],   // run TypeScript specs directly, no build step
    include: ['test/**/*.test.ts'],
    fileParallelism: false,          // one fork → no concurrent HANA access
    coverage: { provider: 'v8', include: ['srv/**/*.{ts,tsx}'] },
  },
});
```

Notes:
- This is a **TypeScript** project: `CDS_TYPESCRIPT=true` + `--import tsx` let the specs
  and CAP handlers run without a separate build step.
- `test:hana` runs `cds bind --exec --profile hana`, so CAP activates the `[hana]`
  profile (→ HANA) with the bound credentials. `test:sqlite` forces
  `NODE_ENV=development` + in-memory SQLite so `cds.test` auto-deploys a fresh DB.
- `cds.test()` returns `{ GET, POST, PUT, DELETE, expect, axios, ... }`; `describe/it`
  come from vitest's global test API.

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
  // HANA's dayname() returns the weekday in UPPERCASE (e.g. FRIDAY), unlike
  // many other databases — assert the exact value you saw on real HANA.
  const { data } = await GET`/odata/v4/worldcup/MatchdaysByWeekday`;
  expect(data.value).to.containSubset([{ ID: 1, weekday: 'FRIDAY' }]);
});

it('fuzzy search tolerates typos (HANA only)', async () => {
  // On SQLite $search is LIKE '%Mbape%' -> []; on HANA it fuzzy-matches Mbappé.
  const { data } = await GET`/odata/v4/worldcup/Players?$search=Mbape`;
  expect(data.value).to.containSubset([{ name: 'Kylian Mbappé' }]);
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

The HANA test instance is already provisioned and bound in this repo
(`hana:recap-test-hana-db`). The everyday loop after changing the model or a
projection is just two npm scripts:

```bash
# 1. (re)deploy the changed model into the bound HANA HDI container
npm run deploy:hana

# 2. run the integration tests against bound HANA
npm run test:hana

# fast inner loop without HANA (in-memory SQLite):
npm run test:sqlite
```

First-time / CI provisioning of a fresh instance (NOT needed for day-to-day work here):

```bash
cf login && cf target -o <org> -s <space>
cf create-service hana hdi-shared recap-test-hana-db   # wait for "create succeeded"
cds bind --to recap-test-hana-db --profile hana        # write the binding
npm run deploy:hana && npm run test:hana
```

Inspect persisted data when an assertion fails:

```bash
npm run repl:hana
# then, in the REPL:
await SELECT.from('WorldCupService.Players')
await SELECT.from('WORLDCUP_TEAM_STANDINGS')
```

## Best Practices

- Keep a dedicated HANA instance for tests only; never test against production data.
- Keep test data deterministic and minimal; do not rely on execution order.
- Never hardcode credentials — always use `cds bind`. Never commit
  `.cdsrc-private.json`.
- Treat HANA tests as an integration gate; keep fast SQLite unit tests too.
- In CI: `cf create-service` → `cds bind --to <inst> --profile hana` →
  `npm run deploy:hana` → `npm run test:hana`, then clean up the instance.

## Common Mistakes

- **Assuming a function is HANA-only when it is portable.** CAP standardizes many
  functions that also work on SQLite — `year/month/day`, `years_between`,
  `months_between`, `days_between`, `round`, `matchespattern`, and `rank() over`. A
  test using these passes on SQLite too, so it does NOT prove HANA-specific behavior
  (false green). Use genuinely non-portable SQL (e.g. `dayname`, `initcap`, regex,
  fuzzy `$search`). See the CAP "portable functions" list before claiming HANA-only.
- **Local (SQLite) script hangs connecting HANA to `:memory:`.** The HANA profile
  is `[hana]`; the `test:sqlite` script MUST set `NODE_ENV=development` (not only
  `CDS_ENV=development`), otherwise CAP loads the HANA driver against `:memory:` and
  the run hangs instead of using SQLite.
- **Stale deployed view after changing a projection.** Changing a CDS view /
  service projection (adding a computed column, `*` + expression, etc.) changes the
  generated HANA view. Run `npm run deploy:hana` BEFORE `npm run test:hana`, or the
  runtime queries the old view and fails with `invalid column name: <NEWCOL>`.
- **Ambiguous redirection with a second projection.** Exposing the same entity twice
  (e.g. a second `as projection on worldcup.Players`) breaks compilation with
  "add @cds.redirection.target …" because associations can't auto-redirect. Mark one
  projection `@cds.redirection.target`, or add the HANA-only column to the existing
  projection via wildcard select (`{ *, dayname(birthDate) as bornOnWeekday }`).

## Definition of Done for New CAP Code

- [ ] New/changed entity, service, handler, or native artifact has a vitest spec.
- [ ] The spec passes under `npm run test:hana` (bound HANA), not only `npm run test:sqlite`.
- [ ] Native-HANA behavior (native views, HANA-only functions/SQL) is asserted on real HANA.
- [ ] No credentials committed; bindings created via `cds bind`.
