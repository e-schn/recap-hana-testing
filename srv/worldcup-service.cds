using { worldcup } from '../db/schema';

/**
 * World Cup Squad Explorer.
 */
@path: '/odata/v4/worldcup'
service WorldCupService {
  @odata.draft.enabled: false
  entity Teams   as projection on worldcup.Teams;

  @cds.redirection.target
  entity Matches as projection on worldcup.Matches;

  entity Players as projection on worldcup.Players;
}
