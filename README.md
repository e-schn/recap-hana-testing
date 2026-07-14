# World Cup Explorer — Testing CAP Applications with SAP HANA Cloud (vitest)

A small SAP CAP project — themed around the **FIFA World Cup 2026** — that
demonstrates **automated testing against SAP HANA Cloud** using **vitest**.

The committed baseline is a **normal CAP app that runs fully on in-memory SQLite,
with all tests green**. That's the point: a working, fast, portable app. During the
demo, **a HANA-only feature is added live** — proven by a test that is
**red on SQLite and green on real HANA**:

1. **Fuzzy search** the CAP-idiomatic way (`$search`).

This README is the **complete runbook**: every command shown in the talk is here so
you can reproduce the demo afterwards.

---

## Setting up vitest

If you're starting from a plain CAP project, add the test tooling first. Install the
dev dependencies (this is exactly what the `init:test-setup` script does):

```bash
npm add -D @cap-js/cds-test @vitest/coverage-v8 @vitest/ui vitest
# or, using the script:
npm run init:test-setup
```

| Package               | Why it's needed                                             |
| --------------------- | ----------------------------------------------------------- |
| `vitest`              | Test runner                                                 |
| `@vitest/coverage-v8` | Code-coverage reporting (`--coverage`)                      |
| `@vitest/ui`          | Browser UI for inspecting test runs (`--ui`)                |
| `@cap-js/cds-test`    | `cds.test` helper for bootstrapping the CAP server in tests |

To run TypeScript tests directly you also need **`tsx`** (`npm add -D tsx`), which
the vitest config below loads via `execArgv`.

Then add a `vitest.config.ts` at the project root:

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    testTimeout: 120_000,
    pool: 'forks',
    execArgv: ['--import', 'tsx'],
    include: ['test/**/*.test.ts'],
    fileParallelism: false,
    coverage: {
      provider: 'v8',
      include: ['srv/**/*.{ts,tsx}']
    }
  },
});
```

Key choices:

- **`pool: 'forks'` + `fileParallelism: false`** run tests sequentially in a single
  fork, so specs never clash over the shared HANA test container.
- **`testTimeout: 120_000`** gives HANA round-trips enough headroom (they're slower
  than in-memory SQLite).
- **`execArgv: ['--import', 'tsx']`** lets tests run TypeScript directly via `tsx`.
- **`coverage.include: ['srv/**/*.{ts,tsx}']`** scopes coverage to service code.

---

## Step 0 — Install

```bash
npm install
npx cds-typer "*"      # generate CDS types (optional; improves TS DX)
```

## Step 1 — Run locally on SQLite (fast feedback)

```bash
npm run test:sqlite
```

Expected result: **all green**.

- `test/Players.test.ts` → **PASS** (Players on SQLite)

That fully-green baseline is the whole point: a working, portable CAP app you can
develop and test at SQLite speed. The HANA-only features come later, live.

> `test:sqlite` forces `CDS_ENV=development` and an in-memory SQLite URL so
> `cds.test` auto-deploys a fresh database each run.

## Step 2 — Cloud Foundry setup

```bash
# Log in (interactive), or use SSO
cf login
# cf login --sso        # one-time passcode flow

# Point at the org/space that has HANA Cloud
cf target -o <your-org> -s <your-space>
cf target                 # verify you are in the right place
```

## Step 3 — Create a dedicated HANA test instance

```bash
cf create-service hana hdi-shared <cap-test-instance>

# Wait until provisioning is finished:
cf services
# look for <cap-test-instance> with "create succeeded"
```

Use a **dedicated instance for tests only** — never point tests at production data.

## Step 4 — Bind the instance to the `hana` profile

```bash
cds bind --to <cap-test-instance> --for hana
```

CAP stores the binding in `.cdsrc-private.json`.
**This file contains credentials and is git-ignored — never commit it.**

## Step 5 — Deploy the data model into the test container

```bash
cds deploy --to hana:<cap-test-instance> --profile hana --auto-undeploy
# convenience script (bound to recap-test-hana-db): npm run deploy:test
```

`--auto-undeploy` drops artifacts that were removed since the last deploy, keeping
the container clean between runs.

## Step 6 — Run the tests against real HANA

```bash
npm run test:hana
# equivalent to:  cds bind --exec --profile hana vitest run
```

Expected result: the **same baseline specs pass on HANA** too
(`Players.test.ts`). The only thing that changed is the
database behind them. From here, follow **DEMO.md** to live-add fuzzy search and
watch it go red on SQLite and green on HANA.

## Step 7 — (Optional) Inspect data in the REPL

```bash
npm run repl:test
# or:  cds bind --exec --profile hana cds repl -- --run .
```

Then, inside the REPL:

```js
await SELECT.from('WorldCupService.Teams')
await SELECT.from('WorldCupService.Players')
```

Useful for troubleshooting failed assertions and checking fixtures.

## Step 8 — Clean up

```bash
cf delete-service <cap-test-instance>
```

---

## CI/CD sequence

Run these in order in a pipeline job (add cleanup at the end):

```bash
cf create-service hana hdi-shared <cap-test-instance>
cds deploy --to hana:<cap-test-instance> --for hana --auto-undeploy
cds bind --exec --profile hana vitest run -- --coverage
cf delete-service <cap-test-instance>   # cleanup (optional)
```

For unattended CI, log in non-interactively first, e.g.:

```bash
cf api <api-endpoint>
cf auth "$CF_USER" "$CF_PASSWORD"       # or use CF_API_TOKEN / service key
cf target -o "$CF_ORG" -s "$CF_SPACE"
```

---

## npm scripts

| Script            | What it does                                                        |
| ----------------- | ------------------------------------------------------------------- |
| `test:sqlite`     | vitest on in-memory **SQLite** (dev profile) — fully green baseline |
| `test:hana`            | vitest against **bound HANA** (`cds bind --exec --profile hana`)    |
| `watch`           | `cds watch` — local dev server + Fiori preview                      |
| `deploy:hana`     | `cds deploy --to hana:... --profile hana --auto-undeploy`           |
| `repl:hana`       | open CAP REPL against bound HANA                                     |
| `build`           | `cds build --production` (generates HANA artifacts under `gen/`)    |

---

## AI-assisted development

`.agents/skills/hana-testing/SKILL.md` is a superpowers-style skill. Any agent that
discovers it will automatically add HANA-backed vitest tests when generating new
CAP entities, services, handlers, or native HANA artifacts — so "test with HANA"
becomes the default, not an afterthought. In the demo, this skill is what makes the
AI generate new HANA-backed features **together with** a HANA-backed test.
