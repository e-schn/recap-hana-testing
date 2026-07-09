# World Cup Squad Explorer — Testing CAP Applications with SAP HANA Cloud (vitest)

A small SAP CAP project — themed around the **FIFA World Cup 2026** — that
demonstrates **automated testing against SAP HANA Cloud** using **vitest**.

The committed baseline is a **normal CAP app that runs fully on in-memory SQLite,
with all tests green**. That's the point: a working, fast, portable app. During the
demo, **two HANA-only features are added live** — each proven by a test that is
**red on SQLite and green on real HANA**:

1. **Fuzzy search** the CAP-idiomatic way (`$search` + `@Search.fuzzinessThreshold`).
2. A **native HANA SQL function** in a CDS view (`dayname()`), generated live by an
   AI agent following the `hana-testing` skill.

These two features live in **DEMO.md**, not in the baseline — so out of the box
`npm run test:sqlite` is fully green.

This README is the **complete runbook**: every command shown in the talk is here so
you can reproduce the demo afterwards.

---

## TL;DR

```bash
npm install
npm run test:sqlite     # SQLite: baseline — fully GREEN
npm run watch           # open the Fiori preview app (Teams / Matches / Players)
# ...set up HANA (below)...
npm test                # HANA: baseline tests pass here too
# ...then follow DEMO.md to live-add the two HANA-only features...
```

---

## Why test with HANA?

Most CAP tests run fast on in-memory SQLite. But some behavior only exists on SAP
HANA and must be tested there:

- Native HANA artifacts: **`.hdbview`**, calculation views, `.hdbtable`,
  `.hdbfunction`, procedures
- HANA-specific SQL and functions (`dayname`, fuzzy `CONTAINS`, spatial/window
  functions)
- Fuzzy `$search` behavior (typo tolerance) that SQLite reduces to a plain `LIKE`
- HDI deployment artifacts and production-like persistence

CAP deliberately standardizes many **portable** functions that behave the same on
every database (e.g. `year/month/day`, `years_between`, `round`, `rank() over`,
`matchespattern`). A good "HANA-only" example must avoid those — which is exactly
why this demo uses `dayname()` and fuzzy `$search`, neither of which SQLite can
reproduce. See
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
  WorldCupService.test.ts        # baseline — passes on SQLite and HANA
  Players.test.ts                # baseline — passes on SQLite and HANA
.agents/skills/
  hana-testing/SKILL.md          # AI skill: always add HANA-backed tests
DEMO.md                          # the live demo runbook (fuzzy search + dayname view)
vitest.config.ts
package.json                     # test profile = HANA; scripts
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

### The two HANA-only features (added live — see DEMO.md)

Both features below are **not** in the committed baseline. They are added on stage
during the demo, each with a test that is **red on SQLite, green on real HANA**.

**1. Fuzzy search (CAP-idiomatic)**

Typo tolerance is added the CAP best-practice way — the standard OData `$search`
query option plus a `@Search.fuzzinessThreshold` annotation, **not** hand-written
native SQL:

```cds
annotate WorldCupService.Players with {
  @Search.fuzzinessThreshold: 0.7
  name;
};
```

On **SQLite**, `$search` compiles to a `LIKE '%…%'` substring match, so
`?$search=Mbape` returns **nothing**. On **SAP HANA Cloud**, the same query
compiles to fuzzy `CONTAINS(… FUZZY)`, so `?$search=Mbape` finds **"Kylian
Mbappé"**. Same standard OData query — only HANA makes it typo-tolerant. See
[Fuzzy Search (served out of the box)](https://cap.cloud.sap/docs/guides/services/served-ootb#fuzzy-search).

**2. Native HANA SQL function in a CDS view (`dayname()`)**

A `PlayerProfiles` view computes each player's birth weekday using the HANA
function `dayname()`:

```cds
@readonly
entity PlayerProfiles as select from worldcup.Players {
  key ID,
      name,
      position,
      birthDate,
      dayname(birthDate) as bornOnWeekday : String   // HANA-only
};
```

`dayname()` is **not** one of CAP's portable functions and is absent from SQLite,
so this errors `no such function: dayname` on SQLite and works on HANA (returning
e.g. `SUNDAY`). This part is generated **live by an AI agent** guided by the
`hana-testing` skill, which forces a HANA-backed test.

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

- `test/WorldCupService.test.ts` → **PASS** (Teams/Matches on SQLite)
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

## Step 4 — Bind the instance to the `test` profile

```bash
cds bind --to <cap-test-instance> --for test
```

CAP stores the binding in `.cdsrc-private.json`.
**This file contains credentials and is git-ignored — never commit it.**

## Step 5 — Deploy the data model into the test container

```bash
cds deploy --to hana:<cap-test-instance> --profile test --auto-undeploy
# convenience script (bound to recap-test-hana-db): npm run deploy:test
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

Expected result: the **same baseline specs pass on HANA** too
(`WorldCupService.test.ts`, `Players.test.ts`). The only thing that changed is the
database behind them. From here, follow **DEMO.md** to live-add fuzzy search and
the `dayname()` view and watch each go red on SQLite and green on HANA.

## Step 7 — (Optional) Inspect data in the REPL

```bash
npm run repl:test
# or:  cds bind --exec --profile test cds repl -- --run .
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
| `test:sqlite`     | vitest on in-memory **SQLite** (dev profile) — fully green baseline |
| `test`            | vitest against **bound HANA** (`cds bind --exec --profile test`)    |
| `test:ts`         | same as `test`, with `CDS_TYPESCRIPT=true`                          |
| `watch`           | `cds watch` — local dev server + Fiori preview                      |
| `deploy:test`     | `cds deploy --to hana:... --profile test --auto-undeploy`           |
| `repl:test`       | open CAP REPL against bound HANA                                     |
| `build`           | `cds build --production` (generates HANA artifacts under `gen/`)    |

---

## AI-assisted development

`.agents/skills/hana-testing/SKILL.md` is a superpowers-style skill. Any agent that
discovers it will automatically add HANA-backed vitest tests when generating new
CAP entities, services, handlers, or native HANA artifacts — so "test with HANA"
becomes the default, not an afterthought. In the demo, this skill is what makes the
AI generate the `dayname()` view **together with** a HANA-backed test.

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

**Fuzzy `$search` returns nothing**
On SQLite, `$search` is only a `LIKE '%…%'` substring match, so a typo like
`?$search=Mbape` finds nothing — that red is expected. Run the fuzzy-search test via
`cds bind --exec --profile test ...` against HANA (with the
`@Search.fuzzinessThreshold` annotation in place) to get the typo-tolerant match.

**`no such function: dayname`**
`dayname()` is HANA-only and does not exist on SQLite — this error means you're
still on SQLite. Run via `cds bind --exec --profile test ...` against the bound HANA
instance, and make sure the model with the `PlayerProfiles` view was deployed
(`npm run deploy:test`).

**Missing/unexpected data**
Confirm deployment succeeded; use the REPL to inspect rows; ensure sample CSVs are
deterministic.

## HANA Functions

[HANA Functions](https://help.sap.com/docs/SAP_HANA_PLATFORM/4fe29514fd584807ac9f2a04f6754767/f12b86a6284c4aeeb449e57eb5dd3ebd.html)