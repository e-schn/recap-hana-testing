# World Cup Squad Explorer — HANA Demo Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the CAP demo into "World Cup Squad Explorer" whose baseline runs fully green on SQLite (no native HANA artifacts), ready for a live demo that adds fuzzy search (Part 4) and a native `dayname()` view (Part 5).

**Architecture:** Plain CAP entities `Teams`, `Matches`, `Players`. All native HANA artifacts (`.hdbview`, `TeamGoals`, `TeamStandings`, `MatchdaysByWeekday`) are removed. Baseline ships only green vitest specs; the two HANA-only specs are created live during the demo (snippets in `DEMO.md`).

**Tech Stack:** SAP CAP (`@sap/cds` 9), `@cap-js/sqlite`, `@cap-js/hana`, vitest + `@cap-js/cds-test`, Fiori Elements annotations.

**Spec:** `docs/superpowers/specs/2026-07-08-worldcup-hana-demo-design.md`

---

## File Structure

- `db/schema.cds` — `Teams`, `Matches`, `Players` (no `TeamGoals`).
- `db/data/worldcup-Players.csv` — new seed (8 players, existing teams).
- `srv/worldcup-service.cds` — exposes `Teams`, `Matches`, `Players` only.
- `app/annotations.cds` — adds `Players` List Report / Object Page.
- `test/WorldCupService.test.ts` — baseline (Teams/Matches), extended with a Players check.
- `test/Players.test.ts` — new baseline spec (Players + association).
- `README.md`, `DEMO.md` — rewritten around the new narrative.
- **Deleted:** `db/hana-views.cds`, `db/src/WORLDCUP_TEAM_STANDINGS.hdbview`, `db/data/worldcup-TeamGoals.csv`, `test/TeamStandings.test.ts`, `test/MatchdaysByWeekday.test.ts`.

---

## Task 1: Remove native HANA artifacts and obsolete entities

**Files:**
- Delete: `db/hana-views.cds`, `db/src/WORLDCUP_TEAM_STANDINGS.hdbview`, `db/data/worldcup-TeamGoals.csv`, `test/TeamStandings.test.ts`, `test/MatchdaysByWeekday.test.ts`
- Modify: `db/schema.cds`, `srv/worldcup-service.cds`

- [ ] **Step 1: Delete obsolete files**

```bash
rm db/hana-views.cds \
   db/src/WORLDCUP_TEAM_STANDINGS.hdbview \
   db/data/worldcup-TeamGoals.csv \
   test/TeamStandings.test.ts \
   test/MatchdaysByWeekday.test.ts
```

If `db/src/` is now empty except `.hdiconfig`, leave `.hdiconfig` in place (harmless); remove `db/src/` only if fully empty.

- [ ] **Step 2: Remove `TeamGoals` from `db/schema.cds`**

Delete the entire `TeamGoals` entity block and its doc comment. Resulting `db/schema.cds` is fully replaced in Task 2, so this step just confirms the block is gone.

- [ ] **Step 3: Trim `srv/worldcup-service.cds` to remove HANA-only entities**

Replace the whole file with:

```cds
using { worldcup } from '../db/schema';

/**
 * World Cup Squad Explorer.
 * Plain persisted entities that run on SQLite and HANA alike.
 * Fuzzy search (Part 4) and the dayname() view (Part 5) are added live
 * during the demo — see DEMO.md.
 */
@path: '/odata/v4/worldcup'
service WorldCupService {
  @odata.draft.enabled: false
  entity Teams   as projection on worldcup.Teams;

  @cds.redirection.target
  entity Matches as projection on worldcup.Matches;

  entity Players as projection on worldcup.Players;
}
```

- [ ] **Step 4: Verify the project still compiles**

Run: `npx cds compile srv/worldcup-service.cds > /dev/null && echo OK`
Expected: `OK` (Task 2 adds `Players`; if run before Task 2 this fails with "no such entity Players" — run Steps of Task 2 first, then re-check).

> Note: reorder if needed — do Task 2 Step 1 before this compile check.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: remove native HANA view and obsolete entities"
```

---

## Task 2: Add the `Players` entity and seed data

**Files:**
- Modify: `db/schema.cds`
- Create: `db/data/worldcup-Players.csv`

- [ ] **Step 1: Replace `db/schema.cds` with the new model**

```cds
namespace worldcup;

/**
 * Domain model for the "World Cup Squad Explorer" demo.
 * Teams, Matches, Players are plain persisted entities — they run on
 * SQLite and HANA alike. No native HANA artifacts in the baseline.
 */

entity Teams {
  key ID           : Integer;
      name         : String;
      grp          : String;   // group A..L
      confederation: String;   // UEFA, CONMEBOL, ...
      coach        : String;
      players      : Association to many Players on players.team = $self;
      matchesHome  : Association to many Matches on matchesHome.homeTeam = $self;
      matchesAway  : Association to many Matches on matchesAway.awayTeam = $self;
}

entity Matches {
  key ID        : Integer;
      stage     : String;      // Group, Round of 16, ...
      city      : String;
      matchDate : Date;
      homeTeam  : Association to Teams;
      awayTeam  : Association to Teams;
      homeGoals : Integer;
      awayGoals : Integer;
}

/**
 * Star players — deliberately hard-to-spell names so fuzzy search
 * (Part 4) has an obvious payoff. `birthDate` feeds the HANA-only
 * dayname() view added live in Part 5.
 */
entity Players {
  key ID        : Integer;
      name      : String;   // Mbappé, Gündoğan, Vinícius Júnior, ...
      position  : String;   // Goalkeeper, Defender, Midfielder, Forward
      shirtNo   : Integer;
      birthDate : Date;
      team      : Association to Teams;
}
```

- [ ] **Step 2: Create `db/data/worldcup-Players.csv`**

```csv
ID;name;position;shirtNo;birthDate;team_ID
1;Kylian Mbappé;Forward;10;1998-12-20;4
2;İlkay Gündoğan;Midfielder;21;1990-10-24;5
3;Vinícius Júnior;Forward;7;2000-07-12;2
4;Aurélien Tchouaméni;Midfielder;8;2000-01-27;4
5;Julián Álvarez;Forward;9;2000-01-31;1
6;Lamine Yamal;Forward;19;2007-07-13;3
7;Bukayo Saka;Forward;7;2001-09-05;6
8;Antonio Rüdiger;Defender;2;1993-03-03;5
```

- [ ] **Step 3: Verify compile**

Run: `npx cds compile srv/worldcup-service.cds > /dev/null && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add db/schema.cds db/data/worldcup-Players.csv
git commit -m "feat: add Players entity with star-player seed data"
```

---

## Task 3: Baseline test — Players served on SQLite (TDD)

**Files:**
- Create: `test/Players.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import cds from '@sap/cds';

// Runs on SQLite under `npm run test:sqlite`, on bound HANA under `npm test`.
const { GET, expect } = cds.test(__dirname + '/..');

describe('Players — baseline (SQLite and HANA)', () => {
  it('serves players with their team', async () => {
    const { data } = await GET`/odata/v4/worldcup/Players?$filter=ID eq 1&$expand=team`;
    expect(data.value[0]).to.include({ name: 'Kylian Mbappé', position: 'Forward' });
    expect(data.value[0].team).to.include({ name: 'France' });
  });

  it('exact substring search still works everywhere', async () => {
    const { data } = await GET`/odata/v4/worldcup/Players?$search=Yamal`;
    expect(data.value).to.containSubset([{ name: 'Lamine Yamal' }]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails first (before seed/entity), then passes**

Run: `npm run test:sqlite -- test/Players.test.ts`
Expected: **PASS** (Tasks 1–2 already added the entity + data). If it fails with "no such table Players", the seed/entity from Task 2 is missing — fix Task 2 first.

- [ ] **Step 3: Extend `test/WorldCupService.test.ts` with a Players smoke check**

Add inside the `describe('WorldCupService — baseline ...')` block, after the existing `it('serves Matches with scores', ...)`:

```ts
  it('serves Players', async () => {
    const { data } = await GET`/odata/v4/worldcup/Players`;
    expect(data.value.length).to.equal(8);
  });
```

- [ ] **Step 4: Run the full SQLite suite — everything green**

Run: `npm run test:sqlite`
Expected: all specs **PASS** (WorldCupService + Players). No red — this is the demo's Part 1 starting point.

- [ ] **Step 5: Commit**

```bash
git add test/Players.test.ts test/WorldCupService.test.ts
git commit -m "test: baseline Players specs (green on SQLite)"
```

---

## Task 4: Fiori annotations for `Players`

**Files:**
- Modify: `app/annotations.cds`

- [ ] **Step 1: Append the `Players` UI annotations**

Add at the end of `app/annotations.cds`:

```cds
////////////////////////////////////////////////////////////////////////////
// Players — List Report + Object Page (Fiori Elements)
////////////////////////////////////////////////////////////////////////////
annotate WorldCupService.Players with @(
  UI: {
    HeaderInfo: {
      $Type         : 'UI.HeaderInfoType',
      TypeName      : 'Player',
      TypeNamePlural: 'Players',
      Title         : { Value: name },
      Description   : { Value: position }
    },
    SelectionFields: [ position ],
    LineItem: [
      { Value: shirtNo,   Label: 'No.' },
      { Value: name,      Label: 'Player' },
      { Value: position,  Label: 'Position' },
      { Value: team.name, Label: 'Team' },
      { Value: birthDate, Label: 'Born' }
    ],
    Facets: [
      { $Type: 'UI.ReferenceFacet', Label: 'Details', Target: '@UI.FieldGroup#Main' }
    ],
    FieldGroup #Main: {
      Data: [
        { Value: name },
        { Value: position },
        { Value: shirtNo },
        { Value: birthDate },
        { Value: team.name, Label: 'Team' }
      ]
    }
  }
) {
  name      @title: 'Player';
  position  @title: 'Position';
  shirtNo   @title: 'No.';
  birthDate @title: 'Born';
};
```

- [ ] **Step 2: Verify compile with the app layer**

Run: `npx cds compile srv/worldcup-service.cds --to json > /dev/null && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add app/annotations.cds
git commit -m "feat: Fiori Players list report and object page"
```

---

## Task 5: Rewrite `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace `README.md`** to describe the new project

Cover, in order:
- **What it is:** World Cup Squad Explorer, a CAP app that runs fully on SQLite; the demo adds HANA-only behavior.
- **Why HANA testing:** same standard queries behave differently on HANA; must be tested there.
- **Project layout:** `db/schema.cds` (Teams/Matches/Players), `db/data/*.csv`, `srv/worldcup-service.cds`, `app/annotations.cds`, `test/*`, `.agents/skills/hana-testing/SKILL.md`.
- **Baseline:** `npm install`, `npm run test:sqlite` (all green), `npm run watch` (Fiori preview for Teams/Matches/Players).
- **HANA testing setup:** profiles in `package.json` (`[development]`=sql, `[test]`=hana); `cds bind --to <instance> --for test`; `npm run deploy:test`; `npm test`.
- **The two HANA-only features** (added during the demo): fuzzy `$search` (Part 4) and `dayname()` view (Part 5), each red on SQLite / green on HANA.
- **AI-assisted development:** `.agents/skills/hana-testing/SKILL.md` makes HANA-backed tests the default.
- **Troubleshooting + HANA functions link.**

Use the current `README.md` as a style reference but remove every mention of `TeamGoals`, `WORLDCUP_TEAM_STANDINGS`, `TeamStandings`, and `MatchdaysByWeekday`. Point the skill path at `.agents/skills/hana-testing/SKILL.md`.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for World Cup Squad Explorer"
```

---

## Task 6: Rewrite `DEMO.md` (12-minute runbook with live snippets)

**Files:**
- Modify: `DEMO.md`

- [ ] **Step 1: Replace `DEMO.md`** with the runbook below

Structure and exact content:

**Pre-flight (before the talk):** switch CF space to the one holding the HANA test instance (currently targeted at `PostgreSQL`); confirm `.cdsrc-private.json` binding; `npm run deploy:test`; one warm `npm test`; free the integrated terminal.

**Part 0 — Framing (0:45):** CAP app; some behavior only works on HANA.

**Part 1 — SQLite baseline (2:00):**
```bash
npm run test:sqlite     # all green
npm run watch           # show Players list in Fiori preview
```

**Part 2 — Set up HANA testing (2:30):** show `[development]`/`[test]` profiles in `package.json`, then:
```bash
cf target                                       # already in the HANA space (pre-flight)
cds bind --to <cap-test-instance> --for test    # writes .cdsrc-private.json (git-ignored)
npm run deploy:test                             # deploy tables into HDI
```

**Part 3 — Same tests on HANA (1:30):**
```bash
npm test        # all green on real HANA
```

**Part 4 — Fuzzy search LIVE (2:30):**

4a. Add fuzziness in `srv/worldcup-service.cds` (below the `Players` projection):
```cds
  entity Players as projection on worldcup.Players;

  annotate WorldCupService.Players with {
    @Search.fuzzinessThreshold: 0.7
    name;
  };
```

4b. Add `test/FuzzySearch.test.ts`:
```ts
import cds from '@sap/cds';
const { GET, expect } = cds.test(__dirname + '/..');

describe('Fuzzy search — HANA only', () => {
  it('finds Mbappé despite the typo "Mbape"', async () => {
    const { data } = await GET`/odata/v4/worldcup/Players?$search=Mbape`;
    expect(data.value).to.containSubset([{ name: 'Kylian Mbappé' }]);
  });

  it('finds Gündoğan from "Gundogan"', async () => {
    const { data } = await GET`/odata/v4/worldcup/Players?$search=Gundogan`;
    expect(data.value).to.containSubset([{ name: 'İlkay Gündoğan' }]);
  });
});
```

4c. Prove it:
```bash
npm run test:sqlite -- test/FuzzySearch.test.ts   # ❌ empty result (LIKE substring)
npm test -- test/FuzzySearch.test.ts              # ✅ fuzzy match on HANA
```

**Part 5 — Skill + AI native function (2:30):**

5a. Open `.agents/skills/hana-testing/SKILL.md`; one line on what it enforces.

5b. Prompt the agent:
> Add a `PlayerProfiles` view to `WorldCupService` that returns each player's birth weekday using the HANA `dayname()` function, and follow the hana-testing skill.

5c. Expected agent edit in `srv/worldcup-service.cds`:
```cds
  @readonly
  entity PlayerProfiles as select from worldcup.Players {
    key ID,
        name,
        position,
        birthDate,
        dayname(birthDate) as bornOnWeekday : String
  };
```

5d. Expected `test/PlayerProfiles.test.ts` (HANA returns the weekday in UPPERCASE — the agent verifies on HANA):
```ts
import cds from '@sap/cds';
const { GET, expect } = cds.test(__dirname + '/..');

describe('PlayerProfiles — HANA dayname() (HANA only)', () => {
  it('returns the birth weekday for each player', async () => {
    const { data } = await GET`/odata/v4/worldcup/PlayerProfiles`;
    // 1998-12-20 is a Sunday (verify casing on HANA)
    expect(data.value).to.containSubset([{ ID: 1, bornOnWeekday: 'SUNDAY' }]);
  });
});
```

5e. Deploy + run:
```bash
npm run deploy:test
npm test
```

**Reset after demo:**
```bash
git checkout -- srv/worldcup-service.cds
git clean -f test/FuzzySearch.test.ts test/PlayerProfiles.test.ts
npm run deploy:test
```

**Timing cheat-sheet** table (0:45 / 2:00 / 2:30 / 1:30 / 2:30 / 2:30 ≈ 11:45).

- [ ] **Step 2: Commit**

```bash
git add DEMO.md
git commit -m "docs: rewrite 12-minute demo runbook"
```

---

## Task 7: HANA verification pass (executor runs against bound HANA)

**Files:** none (verification only)

- [ ] **Step 1: Target the correct CF space and confirm the instance**

Run:
```bash
cf target -o <org> -s <space-with-hana>
cf services   # <cap-test-instance> = "create succeeded"
```

- [ ] **Step 2: Deploy the reworked model**

Run: `npm run deploy:test`
Expected: deployment succeeds (only `Teams`, `Matches`, `Players` tables — no view).

- [ ] **Step 3: Run the baseline suite on HANA**

Run: `npm test`
Expected: `WorldCupService` + `Players` specs **PASS** on real HANA.

- [ ] **Step 4: Dry-run the live parts once (de-risk the demo)**

Temporarily apply the Part 4 and Part 5 snippets from `DEMO.md`, then:
```bash
npm run deploy:test
npm run test:sqlite -- test/FuzzySearch.test.ts test/PlayerProfiles.test.ts   # expect RED
npm test -- test/FuzzySearch.test.ts test/PlayerProfiles.test.ts              # expect GREEN
```
Confirm the `dayname()` casing matches the assertion (`SUNDAY`); adjust `DEMO.md` if HANA returns a different case. Then revert the live snippets:
```bash
git checkout -- srv/worldcup-service.cds
git clean -f test/FuzzySearch.test.ts test/PlayerProfiles.test.ts
```

- [ ] **Step 5: Commit any DEMO.md casing fixes**

```bash
git add DEMO.md
git commit -m "docs: confirm dayname() casing for demo"
```

---

## Self-Review

- **Spec coverage:** baseline SQLite-only (Tasks 1–4), all-green baseline (Task 3), fuzzy Part 4 + dayname Part 5 (Task 6 DEMO snippets + Task 7 verification), README/DEMO rewrite (Tasks 5–6), removal of native artifacts (Task 1). ✅
- **Placeholder scan:** `<org>`, `<space-with-hana>`, `<cap-test-instance>` are deployment-environment values the presenter fills in; `SUNDAY` casing is verified in Task 7. No code placeholders.
- **Type consistency:** entity/element names (`Players.name`, `birthDate`, `team`, `PlayerProfiles.bornOnWeekday`) match across schema, service, tests, and DEMO snippets.

---

## Execution Handoff

Two execution options:

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks.
2. **Inline Execution** — execute tasks in this session with checkpoints.

Note: Tasks 1–6 are local (SQLite) and do not need HANA or the wedged terminal for editing; Task 7 requires a working terminal + CF/HANA access.
