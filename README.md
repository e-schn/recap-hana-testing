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

## Why test with HANA?

Most CAP tests run fast on in-memory SQLite. But some behavior only exists on SAP
HANA and must be tested there:

- Native HANA artifacts: **`.hdbview`**, calculation views, `.hdbtable`,
  `.hdbfunction`, procedures
- HANA-specific SQL and functions (fuzzy `CONTAINS`, spatial/window functions)
- Fuzzy `$search` behavior (typo tolerance) that SQLite reduces to a plain `LIKE`
- HDI deployment artifacts and production-like persistence

CAP deliberately standardizes many **portable** functions that behave the same on
every database (e.g. `year/month/day`, `years_between`, `round`, `rank() over`,
`matchespattern`). A good "HANA-only" example must avoid those — which is exactly
why this demo uses fuzzy `$search`, which SQLite cannot reproduce. See
[CAP-level, portable databases](https://cap.cloud.sap/docs/guides/databases/cap-level-dbs).

---

## The app (Fiori Elements)

`app/annotations.cds` adds UI annotations so the service can be shown as a small
Fiori Elements app:

- **Teams** — List Report + Object Page (team, group, confederation, coach)
- **Matches** — List Report + Object Page (stage, city, date, home/away, score)
- **Players** — List Report + Object Page (name, position, shirt no, birth date, team)

Run `npm run watch` and open <http://localhost:4004> → follow the **Fiori preview**
links, or go directly to:

```
http://localhost:4004/$fiori-preview/WorldCupService/Teams#preview-app
http://localhost:4004/$fiori-preview/WorldCupService/Matches#preview-app
http://localhost:4004/$fiori-preview/WorldCupService/Players#preview-app
```

The preview runs on SQLite, so Teams/Matches/Players show data immediately — good
for explaining "what kind of app this is" before diving into the HANA part. The
Players list includes deliberately hard-to-spell names (Kylian Mbappé, İlkay
Gündoğan, Vinícius Júnior, …) so the fuzzy-search payoff later is obvious.

---

## Project layout

```
app/
  annotations.cds                # Fiori Elements UI annotations (Teams, Matches, Players)
db/
  schema.cds                     # Teams, Matches, Players (plain persisted tables)
  data/
    worldcup-Teams.csv           # deterministic sample data (CSV)
    worldcup-Matches.csv
    worldcup-Players.csv
srv/
  worldcup-service.cds           # WorldCupService: Teams, Matches, Players
  worldcup-service.ts
test/
  Players.test.ts                # baseline — passes on SQLite and HANA
.agents/skills/
  hana-testing/SKILL.md          # AI skill: always add HANA-backed tests
vitest.config.ts
package.json                     # hana profile = HANA; scripts
```

The domain model in `db/schema.cds` is entirely plain, persisted entities:

- **Teams** — `ID`, `name`, `grp`, `confederation`, `coach`; associations to
  `Players` and `Matches`.
- **Matches** — `ID`, `stage`, `city`, `matchDate`, `homeTeam`, `awayTeam`,
  `homeGoals`, `awayGoals`.
- **Players** — `ID`, `name`, `position`, `shirtNo`, `birthDate`, `team`
  association. Seeded from `db/data/worldcup-Players.csv` with star players whose
  accented names (Mbappé, Gündoğan, Vinícius Júnior, Tchouaméni, Álvarez, Yamal,
  Saka, Rüdiger) make fuzzy search worth having.

`srv/worldcup-service.cds` exposes **only** `Teams`, `Matches`, and `Players`.
There are **no HANA-only entities in the baseline** — everything here runs on both
SQLite and HANA.

### The HANA-only feature

The feature below is **not** in the committed baseline. It is added on stage
during the demo, with a test that is **red on SQLite, green on real HANA**.

**Fuzzy search (CAP-idiomatic)**

Typo tolerance is added the CAP best-practice way — the standard OData `$search`
query option.

On **SQLite**, `$search` compiles to a `LIKE '%…%'` substring match, so
`?$search=Mbape` returns **nothing**. On **SAP HANA Cloud**, the same query
compiles to fuzzy `CONTAINS(… FUZZY)`, so `?$search=Mbape` finds **"Kylian
Mbappé"**. Same standard OData query — only HANA makes it typo-tolerant. See
[Fuzzy Search (served out of the box)](https://cap.cloud.sap/docs/guides/services/served-ootb#fuzzy-search).

---

## Prerequisites

- Node.js 20+ and npm
- `@sap/cds-dk` (`npm i -g @sap/cds-dk`) — or use the local one via `npx cds`
- Cloud Foundry CLI (`cf`) — <https://github.com/cloudfoundry/cli>
- Access to an SAP BTP subaccount/space with the **SAP HANA Cloud** service entitlement
- A running SAP HANA Cloud instance in that space (to create HDI containers against)

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
cds bind --to <cap-test-instance> --for hana
cds deploy --to hana:<cap-test-instance> --profile hana --auto-undeploy
cds bind --exec --profile hana vitest run
cf delete-service <cap-test-instance>   # cleanup
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
| `test:ts`         | same as `test`, with `CDS_TYPESCRIPT=true`                          |
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

---

## Troubleshooting

**`npm test` says no HDI container / Service Manager bound**
Run `cds bind --to <cap-test-instance> --for hana` first; confirm
`.cdsrc-private.json` exists.

**Deployment fails**
`cf services` (is the instance "create succeeded"?), check `cf target` org/space and
permissions, re-run deploy with `--profile hana` explicit.

**Tests still use SQLite**
Ensure `package.json` has `"[hana]": { "db": "hana" }` and that you run via
`cds bind --exec --profile hana ...` (not plain `vitest`).

**Fuzzy `$search` returns nothing**
On SQLite, `$search` is only a `LIKE '%…%'` substring match, so a typo like
`?$search=Mbape` finds nothing — that red is expected. Run the fuzzy-search test via
`cds bind --exec --profile hana ...` against HANA (with the
`@Search.fuzzinessThreshold` annotation in place) to get the typo-tolerant match.

**Missing/unexpected data**
Confirm deployment succeeded; use the REPL to inspect rows; ensure sample CSVs are
deterministic.