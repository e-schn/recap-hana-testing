import cds from '@sap/cds';

/**
 * HANA-native test #2 — HANA built-in SQL function used in the CDS service.
 *
 * `MatchdaysByWeekday` exposes `dayname(matchDate)` (see srv/worldcup-service.cds).
 * `DAYNAME` is a native SAP HANA function; SQLite has no such function.
 * Therefore:
 *
 *   - `npm run test:sqlite` (SQLite)  -> this test FAILS (no such function: dayname).
 *   - `npm test` (cds bind --exec --profile test, real HANA) -> this test PASSES.
 *
 * Expected weekday names from db/data/worldcup-Matches.csv.
 * Note: SAP HANA's DAYNAME() returns the weekday in UPPERCASE:
 *   ID 1  2026-06-12 -> FRIDAY
 *   ID 2  2026-06-13 -> SATURDAY
 *   ID 5  2026-07-01 -> WEDNESDAY
 */
const { GET, expect } = cds.test(__dirname + '/..');

describe('MatchdaysByWeekday — HANA dayname() function (HANA only)', () => {
  it('returns the weekday name for each match date', async () => {
    const { data } = await GET`/odata/v4/worldcup/MatchdaysByWeekday`;

    expect(data.value).to.containSubset([
      { ID: 1, weekday: 'FRIDAY' },
      { ID: 2, weekday: 'SATURDAY' },
      { ID: 5, weekday: 'WEDNESDAY' },
    ]);
  });
});
