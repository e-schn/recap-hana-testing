using { worldcup } from '../db/schema';
using { WORLDCUP_TEAM_STANDINGS } from '../db/hana-views';

/**
 * World Cup service.
 * - Teams / Matches are the plain persisted entities (work on SQLite and HANA).
 * - TeamStandings projects the native HANA SQL view WORLDCUP_TEAM_STANDINGS
 *   (RANK window function), so it only exists on SAP HANA Cloud.
 * - MatchdaysByWeekday uses the HANA built-in function dayname(), which does
 *   not exist on SQLite — so reading it only works against SAP HANA Cloud.
 */
@path: '/odata/v4/worldcup'
service WorldCupService {

  @odata.draft.enabled: false
  entity Teams   as projection on worldcup.Teams;

  @cds.redirection.target
  entity Matches as projection on worldcup.Matches;

  // Native HANA SQL view: ranks teams per stage by total goals.
  @readonly
  entity TeamStandings as projection on WORLDCUP_TEAM_STANDINGS;

  // HANA-native SQL function dayname() — unavailable on SQLite.
  @readonly
  entity MatchdaysByWeekday as select from worldcup.Matches {
    key ID,
        city,
        matchDate,
        dayname(matchDate) as weekday : String
  };
}
