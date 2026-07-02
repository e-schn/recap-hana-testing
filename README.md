# reCAP Demo — Testing CAP Applications with SAP HANA Cloud (vitest)

A minimal SAP CAP project — themed around the **FIFA World Cup 2026** — that
demonstrates **automated testing against SAP HANA Cloud** using **vitest**. The
centerpieces are a **native HANA SQL view** (`WORLDCUP_TEAM_STANDINGS`, using a
`RANK()` window function) exposed through a CDS entity, and a **HANA-only SQL
function** (`dayname()`) used directly in the CDS service — both validated on a
real HANA instance, something in-memory SQLite cannot do. It also ships **Fiori
Elements annotations**, so you can open a small List Report / Object Page app to
show what kind of app this is.

This README is the **complete runbook**: every command shown in the talk is here so
you can reproduce the demo afterwards.

---

## TL;DR

```bash
npm install
npm run test:sqlite     # SQLite: baseline passes, HANA-only tests FAIL (by design)
npm run watch          # open the Fiori preview app (Teams / Matches)
# ...set up HANA (below)...
npm test               # HANA: everything passes
```

---

## Why test with HANA?

Most CAP tests run fast on in-memory SQLite. But some behavior only exists on SAP
HANA and must be tested there:

- Native HANA artifacts: **`.hdbview`**, calculation views, `.hdbtable`, `.hdbfunction`, procedures
- HANA-specific SQL and functions (`dayname`, regex, aggregations, window/spatial functions)
- Entities annotated `@cds.persistence.exists`
- HDI deployment artifacts and production-like persistence

This project shows the smallest end-to-end example: a native HANA view that ranks
World Cup teams and a HANA `dayname()` function — both only work on HANA.

---

## The app (Fiori Elements)

`app/annotations.cds` adds UI annotations so the service can be shown as a small
Fiori Elements app:

- **Teams** — List Report + Object Page (team, group, confederation, coach)
- **Matches** — List Report + Object Page (stage, city, date, home/away, score)

Run `npm run watch` and open <http://localhost:4004> → follow the **Fiori preview**
links, or go directly to:

```
http://localhost:4004/$fiori-preview/WorldCupService/Teams#preview-app
http://localhost:4004/$fiori-preview/WorldCupService/Matches#preview-app
```

The preview runs on SQLite, so Teams/Matches show data immediately — good for
explaining "what kind of app this is" before diving into the HANA part.

---

## Project layout

```
app/
  annotations.cds                # Fiori Elements UI annotations (Teams, Matches)
db/
  schema.cds                     # Teams, Matches, TeamGoals (plain tables)
  hana-views.cds                 # WORLDCUP_TEAM_STANDINGS  (@cds.persistence.exists)
  data/                          # deterministic sample data (CSV)
  src/
    .hdiconfig                   # maps .hdbview -> view plugin (and other artifacts)
    WORLDCUP_TEAM_STANDINGS.hdbview   # the native HANA SQL view (RANK window function)
srv/
  worldcup-service.cds           # WorldCupService: Teams, Matches, TeamStandings, MatchdaysByWeekday
  worldcup-service.ts
test/
  WorldCupService.test.ts        # baseline — passes on SQLite and HANA
  TeamStandings.test.ts          # native HANA view — passes ONLY on HANA
  MatchdaysByWeekday.test.ts     # HANA dayname() function — passes ONLY on HANA
skills/
  hana-testing/SKILL.md          # AI skill: always add HANA-backed tests
vitest.config.ts
package.json                     # test profile = HANA; scripts
```

### How the native HANA logic is wired

**1. Native SQL view (`TeamStandings`)**

1. `db/src/WORLDCUP_TEAM_STANDINGS.hdbview` ranks teams within each stage by
   `SUM(goals)` using `RANK() OVER (PARTITION BY stage ORDER BY SUM(goals) DESC)`,
   reading from the `worldcup_TeamGoals` table.
2. `db/hana-views.cds` exposes it to CDS:

   ```cds
   @cds.persistence.exists          // object exists in HDI; CAP won't create it
   entity WORLDCUP_TEAM_STANDINGS {
     key TEAM          : String;
     key STAGE         : String;
         GOALS         : Integer;
         RANK_IN_STAGE : Integer;
   }
   ```

   The entity has **no namespace** so its SQL name is exactly
   `WORLDCUP_TEAM_STANDINGS`, matching the `.hdbview` object id.
3. `srv/worldcup-service.cds` projects it as `TeamStandings`.

On SQLite the view does not exist, so reading `TeamStandings` throws
`no such table: WORLDCUP_TEAM_STANDINGS` — that red is the whole point of the demo.

**2. HANA-only function (`MatchdaysByWeekday`)**

`srv/worldcup-service.cds` also defines a projection that calls the native HANA
function `dayname()`:

```cds
entity MatchdaysByWeekday as select from worldcup.Matches {
  key ID, city, matchDate,
      dayname(matchDate) as weekday : String   // HANA-only
};
```

CAP passes `dayname(...)` straight to SQL. On SQLite this throws
`no such function: dayname`; on HANA it returns `Friday`, `Saturday`, … — again
provable only against real HANA.

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

Expected result:

- `test/WorldCupService.test.ts` → **PASS** (Teams/Matches work on SQLite)
- `test/TeamStandings.test.ts` → **FAIL** with `no such table: WORLDCUP_TEAM_STANDINGS`
- `test/MatchdaysByWeekday.test.ts` → **FAIL** with `no such function: dayname`

This is intentional: it proves the native HANA view and the HANA-only function
can't be validated on SQLite.

> `test:sqlite` forces `NODE_ENV=development` and an in-memory SQLite URL so
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

## Step 4 — Bind the instance to the `test` profile

```bash
cds bind --to <cap-test-instance> --for test
```

CAP stores the binding in `.cdsrc-private.json`.
**This file contains credentials and is git-ignored — never commit it.**

## Step 5 — Deploy the data model into the test container

```bash
cds deploy --to hana:<cap-test-instance> --profile test --auto-undeploy
```

`--auto-undeploy` drops artifacts that were removed since the last deploy, keeping
the container clean between runs.

## Step 6 — Run the tests against real HANA

```bash
npm test
# equivalent to:  cds bind --exec --profile test vitest run
```

TypeScript projects (this one) also have:

```bash
npm run test:ts
# CDS_TYPESCRIPT='true' cds bind --exec --profile test vitest run
```

Expected result: **all tests pass**, including `TeamStandings` returning
`Argentina/Group = 7 (#1)`, `Spain/Group = 7 (#1)`, `France/Group = 6 (#3)`, and
`MatchdaysByWeekday` returning `Friday`, `Saturday`, … for the match dates.

## Step 7 — (Optional) Inspect data in the REPL

```bash
npm run repl:test
# or:  cds bind --exec --profile test cds repl -- --run .
```

Then, inside the REPL:

```js
await SELECT.from('WorldCupService.Teams')
await SELECT.from('WORLDCUP_TEAM_STANDINGS')
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
cds bind --to <cap-test-instance> --for test
cds deploy --to hana:<cap-test-instance> --profile test --auto-undeploy
cds bind --exec --profile test vitest run
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
| `test:sqlite`      | vitest on in-memory **SQLite** (dev profile)                        |
| `test`            | vitest against **bound HANA** (`cds bind --exec --profile test`)    |
| `test:ts`         | same as `test`, with `CDS_TYPESCRIPT=true`                          |
| `watch`           | `cds watch` — local dev server + Fiori preview                      |
| `deploy:test`     | `cds deploy --to hana:... --profile test --auto-undeploy`           |
| `repl:test`       | open CAP REPL against bound HANA                                     |
| `build`           | `cds build --production` (generates HANA artifacts under `gen/`)    |

---

## AI-assisted development

`skills/hana-testing/SKILL.md` is a superpowers-style skill. Any agent that
discovers it will automatically add HANA-backed vitest tests when generating new
CAP entities, services, handlers, or native HANA artifacts — so "test with HANA"
becomes the default, not an afterthought.

---

## Troubleshooting

**`npm test` says no HDI container / Service Manager bound**
Run `cds bind --to <cap-test-instance> --for test` first; confirm
`.cdsrc-private.json` exists.

**Deployment fails**
`cf services` (is the instance "create succeeded"?), check `cf target` org/space and
permissions, re-run deploy with `--profile test` explicit.

**Tests still use SQLite**
Ensure `package.json` has `"[test]": { "db": "hana" }` and that you run via
`cds bind --exec --profile test ...` (not plain `vitest`).

**`no such table: WORLDCUP_TEAM_STANDINGS` on HANA**
The native view wasn't deployed. Re-run `cds deploy ... --profile test`; verify
`db/src/.hdiconfig` maps `hdbview` and that
`db/src/WORLDCUP_TEAM_STANDINGS.hdbview` references the correct source table name
(`worldcup_TeamGoals`).

**`no such function: dayname` on HANA**
You're still on SQLite — `dayname()` only exists on HANA. Run the tests via
`cds bind --exec --profile test ...` against the bound HANA instance.

**Missing/unexpected data**
Confirm deployment succeeded; use the REPL to inspect rows; ensure sample CSVs are
deterministic.

## HANA Functions

[HANA Functions](https://help.sap.com/docs/SAP_HANA_PLATFORM/4fe29514fd584807ac9f2a04f6754767/f12b86a6284c4aeeb449e57eb5dd3ebd.html)