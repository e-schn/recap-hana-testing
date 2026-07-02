import cds from '@sap/cds';

/**
 * HANA-native test #1 — native SQL view with a window function.
 *
 * `TeamStandings` projects the native HANA view WORLDCUP_TEAM_STANDINGS
 * (db/src/WORLDCUP_TEAM_STANDINGS.hdbview). It ranks teams within each stage by
 * total goals via `RANK() OVER (PARTITION BY stage ORDER BY SUM(goals) DESC)`.
 *
 * The view is an HDI artifact that ONLY exists on SAP HANA — it is never
 * created on SQLite. Therefore:
 *
 *   - `npm run test:sqlite` (SQLite)  -> this test FAILS (object does not exist).
 *     That red is the whole point: it proves why HANA-backed tests are needed.
 *   - `npm test` (cds bind --exec --profile test, real HANA) -> this test PASSES.
 *
 * Expected aggregation from db/data/worldcup-TeamGoals.csv:
 *   Group:        Argentina 7 (#1), Spain 7 (#1), France 6 (#3), Brazil 5 (#4), Germany 2 (#5)
 *   Round of 16:  France 3 (#1), Argentina 2 (#2)
 */
const { GET, expect } = cds.test(__dirname + '/..');

describe('TeamStandings — native HANA SQL view with RANK() (HANA only)', () => {
  it('ranks teams within each stage by total goals', async () => {
    const { data } = await GET`/odata/v4/worldcup/TeamStandings`;

    expect(data.value).to.containSubset([
      { TEAM: 'Argentina', STAGE: 'Group', GOALS: 7, RANK_IN_STAGE: 1 },
      { TEAM: 'Spain', STAGE: 'Group', GOALS: 7, RANK_IN_STAGE: 1 },
      { TEAM: 'France', STAGE: 'Group', GOALS: 6, RANK_IN_STAGE: 3 },
      { TEAM: 'France', STAGE: 'Round of 16', GOALS: 3, RANK_IN_STAGE: 1 },
      { TEAM: 'Argentina', STAGE: 'Round of 16', GOALS: 2, RANK_IN_STAGE: 2 },
    ]);
  });

  it('returns one row per team/stage combination', async () => {
    const { data } = await GET`/odata/v4/worldcup/TeamStandings`;
    // 5 Group rows + 2 Round of 16 rows
    expect(data.value.length).to.equal(7);
  });
});
