using { worldcup } from '../db/schema';

/**
 * World Cup Squad Explorer.
 * Plain persisted entities that run on SQLite and HANA alike.
 * Fuzzy search (Part 4) and the dayname() column on Players (Part 5) are
 * added live during the demo — see DEMO.md.
 */
@path: '/odata/v4/worldcup'
service WorldCupService {
  @odata.draft.enabled: false
  entity Teams   as projection on worldcup.Teams;

  @cds.redirection.target
  entity Matches as projection on worldcup.Matches;

  entity Players as projection on worldcup.Players;
}
