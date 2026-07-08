# World Cup Squad Explorer — HANA Testing Demo (Redesign)

- **Date:** 2026-07-08
- **Status:** Draft for review
- **Owner:** Armin
- **Context:** reCAP conference demo (~12 min) showing why some CAP behavior must be
  tested against real SAP HANA Cloud, not only in-memory SQLite.

## 1. Goal

Rework the existing CAP demo into a more engaging "World Cup Squad Explorer" whose
**baseline runs entirely on SQLite (all tests green, zero native HANA artifacts)**.
The demo then adds, live, two things that only work on real HANA — each proven by a
test that is red on SQLite and green on HANA:

1. **Part 4 (human, idiomatic):** fault-tolerant **fuzzy search** via CAP's OOTB
   `$search` + `@Search.fuzzinessThreshold`.
2. **Part 5 (AI-assisted):** a **native HANA SQL function in a CDS view** —
   `dayname(birthDate)` — added by an AI agent guided by the `hana-testing` skill,
   which forces a HANA-backed test.

## 2. Why this design

- **SQLite-only baseline** makes the "everything is green and fast" starting point
  honest — no HANA dependency to run the app locally.
- **Fuzzy search** is the CAP-idiomatic way to get typo tolerance. It is not
  hand-written SQL; the same standard OData query simply behaves differently per DB
  (`LIKE` substring on SQLite → empty result; fuzzy `CONTAINS` on HANA → match). This
  teaches the real lesson: *DB-specific behavior needs DB-specific tests.*
- **`dayname()`** is genuinely HANA-only. It is **not** in CAP's portable function
  list (unlike `years_between`, `month`, `round`, `rank() over`, `matchespattern`,
  etc.) and has no SQLite equivalent, so it errors on SQLite and works on HANA — the
  crisp red→green needed for the native-artifact story.

## 3. Non-goals

- No `.hdbview`, `.hdbtable`, `.hdbfunction`, or `@cds.persistence.exists` artifacts
  in the baseline.
- No custom native-SQL handlers for search (fuzzy is OOTB).
- No change to the CF/HANA provisioning story (instance already exists in CF; the
  demo does not create it live).

## 4. Domain model (`db/schema.cds`)

Namespace `worldcup`.

```cds
entity Teams {
  key ID           : Integer;
      name         : String;
      grp          : String;
      confederation: String;
      coach        : String;
      players      : Association to many Players on players.team = $self;
      matchesHome  : Association to many Matches on matchesHome.homeTeam = $self;
      matchesAway  : Association to many Matches on matchesAway.awayTeam = $self;
}

entity Matches {
  key ID        : Integer;
      stage     : String;
      city      : String;
      matchDate : Date;
      homeTeam  : Association to Teams;
      awayTeam  : Association to Teams;
      homeGoals : Integer;
      awayGoals : Integer;
}

// NEW — the star of the fuzzy-search demo.
entity Players {
  key ID        : Integer;
      name      : String;   // hard-to-spell names: Mbappé, Gündoğan, Højlund, …
      position  : String;   // Goalkeeper, Defender, Midfielder, Forward
      shirtNo   : Integer;
      birthDate : Date;     // used by the Part-5 dayname() view
      team      : Association to Teams;
}
```

**Removed** vs. current project: `TeamGoals` entity, `db/hana-views.cds`,
`db/src/WORLDCUP_TEAM_STANDINGS.hdbview` (+ `.hdiconfig` if unused), and the
`worldcup-TeamGoals.csv` seed.

### Seed data (illustrative, finalized in implementation)

Players chosen for names people misspell, mapped to the **existing** six teams
(Argentina=1, Brazil=2, Spain=3, France=4, Germany=5, England=6) so Teams/Matches
data is unchanged:

| ID | name | position | shirtNo | birthDate | team_ID |
|----|------|----------|---------|-----------|---------|
| 1 | Kylian Mbappé | Forward | 10 | 1998-12-20 | 4 (France) |
| 2 | İlkay Gündoğan | Midfielder | 21 | 1990-10-24 | 5 (Germany) |
| 3 | Vinícius Júnior | Forward | 7 | 2000-07-12 | 2 (Brazil) |
| 4 | Aurélien Tchouámeni | Midfielder | 8 | 2000-01-27 | 4 (France) |
| 5 | Julián Álvarez | Forward | 9 | 2000-01-31 | 1 (Argentina) |
| 6 | Lamine Yamal | Forward | 19 | 2007-07-13 | 3 (Spain) |
| 7 | Bukayo Saka | Forward | 7 | 2001-09-05 | 6 (England) |
| 8 | Antonio Rüdiger | Defender | 2 | 1993-03-03 | 5 (Germany) |

Data kept deterministic and minimal.

## 5. Service (`srv/worldcup-service.cds`)

```cds
@path: '/odata/v4/worldcup'
service WorldCupService {
  @odata.draft.enabled: false
  entity Teams   as projection on worldcup.Teams;
  entity Matches as projection on worldcup.Matches;

  // Fuzzy search target (Part 4). fuzziness added live during the demo.
  entity Players as projection on worldcup.Players;
}
```

Part 4 and Part 5 edits are applied **live on stage**, not pre-committed (they are
the demo). Their target snippets are documented in `DEMO.md`.

## 6. Part 4 — Fuzzy search (CAP-idiomatic)

**Live edit:** annotate the searchable element(s) on `Players`:

```cds
entity Players : worldcup.Players {
  @Search.fuzzinessThreshold: 0.7
  name;
}
```

(or annotate in `db/schema.cds` / via `annotate`). Ensure `@cds.search` includes
`name` (default already includes String elements).

**Config:** confirm Node fuzzy search is active on HANA (`cds.hana.fuzzy`; on by
default — verify during implementation). SQLite has no fuzzy and falls back to
case-insensitive substring.

**Behavior / test (`test/FuzzySearch.test.ts`):**

```ts
const { data } = await GET`/odata/v4/worldcup/Players?$search=Mbape`;
expect(data.value).to.containSubset([{ name: 'Kylian Mbappé' }]);
```

- SQLite: `$search=Mbape` → `LIKE '%Mbape%'` → **[]** → test **fails**.
- HANA: fuzzy match → returns Mbappé → test **passes**.

Second assertion (e.g. `?$search=Gundogan` → Gündoğan) reinforces the point.

## 7. Part 5 — Native HANA function in a CDS view (AI-assisted)

**Prompt used live** (agent has the `hana-testing` skill):

> Add a `PlayerProfiles` view to `WorldCupService` that also returns each player's
> birth weekday using the HANA `dayname()` function, and follow the hana-testing
> skill.

**Expected agent output:**

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

Plus `test/PlayerProfiles.test.ts`:

```ts
const { data } = await GET`/odata/v4/worldcup/PlayerProfiles`;
expect(data.value).to.containSubset([
  { ID: 1, bornOnWeekday: <weekday for 1998-12-20> },
]);
```

- SQLite: `no such function: dayname` → **fails**.
- HANA: returns the weekday → **passes**.

> **Casing note:** verify HANA `dayname()` output casing on the real instance
> (the previous project asserted uppercase, e.g. `SUNDAY`). The skill mandates
> asserting against real HANA, so the exact value is confirmed at implementation time.

## 8. Tests overview

| File | Scope | SQLite | HANA |
|------|-------|--------|------|
| `test/WorldCupService.test.ts` | Teams/Matches/Players baseline CRUD | ✅ | ✅ |
| `test/Players.test.ts` | Players read + associations | ✅ | ✅ |
| `test/FuzzySearch.test.ts` | Part 4 `$search` fuzzy (**created live**) | ❌ (empty) | ✅ |
| `test/PlayerProfiles.test.ts` | Part 5 `dayname()` (**created live**) | ❌ (no fn) | ✅ |

**Baseline repo ships only the two green specs**, so `npm run test:sqlite` is fully
green at the start of the demo (Part 1 “working SQLite setup”). `FuzzySearch` and
`PlayerProfiles` are **created live** during Parts 4 and 5 — their exact snippets
live in `DEMO.md`. Once added, they are red on SQLite and green on `npm test` (HANA).

## 9. Files to add / change / remove

**Add (baseline repo):** `Players` entity + seed `db/data/worldcup-Players.csv`;
`Players` in Fiori annotations; `test/Players.test.ts`. (`FuzzySearch.test.ts` +
the `@Search.fuzzinessThreshold` annotation are added live in Part 4;
`PlayerProfiles` view + `test/PlayerProfiles.test.ts` are created live in Part 5 —
both documented in `DEMO.md`, not pre-committed.)

**Change:** `db/schema.cds`, `srv/worldcup-service.cds`, `app/annotations.cds`,
`README.md`, `DEMO.md`, existing tests referencing removed entities, `package.json`
scripts if they name removed artifacts.

**Remove:** `db/hana-views.cds`, `db/src/WORLDCUP_TEAM_STANDINGS.hdbview`,
`TeamGoals` entity + `worldcup-TeamGoals.csv`, `TeamStandings` +
`MatchdaysByWeekday` from the service, `test/TeamStandings.test.ts`,
`test/MatchdaysByWeekday.test.ts`, and (if now unused) the `deploy:test`/gen native
view references and `db/src/.hdiconfig`.

## 10. Demo flow (~12 min) — for `DEMO.md`

0. Framing (0:45) — CAP app; some behavior only works on HANA.
1. SQLite baseline green (2:00) — `npm run test:sqlite`, show Fiori Players list.
2. Set up HANA testing (2:30) — profiles in `package.json`; `cds bind`; deploy
   (instance already in CF; not created live).
3. Same tests on HANA (1:30) — `npm test` → green.
4. Fuzzy search live (2:30) — add `@Search.fuzzinessThreshold`, `?$search=Mbape`;
   red on SQLite, green on HANA.
5. Skill + AI native function (2:30) — show `hana-testing` skill; prompt agent to add
   `dayname()` `PlayerProfiles` view; it auto-writes a HANA test; deploy + `npm test`.

## 11. Risks / mitigations

- **Fuzzy default threshold** may not tolerate `Mbape`→`Mbappé` without the
  annotation. Mitigation: set `@Search.fuzzinessThreshold: 0.7` explicitly and verify
  on HANA during implementation.
- **`dayname()` casing** unknown until run on HANA. Mitigation: assert after
  verifying on the bound instance (skill requires this).
- **CF target space** — currently `PostgreSQL`; must switch to the space holding the
  HANA test instance before deploy/`npm test`. Flagged in `DEMO.md` pre-flight.
- **Terminal / network** must be free and CF logged in before the talk.

## 12. Definition of done

- Baseline `npm run test:sqlite`: baseline specs green; fuzzy + profiles specs red.
- `npm test` on bound HANA: all green.
- README + DEMO rewritten around this narrative.
- No native HANA artifacts remain in the baseline; no credentials committed.
