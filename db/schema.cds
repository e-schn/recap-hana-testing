namespace worldcup;

/**
 * Domain model for the "Testing with HANA Cloud" demo — FIFA World Cup 2026.
 *
 * Teams and Matches are plain persisted entities (tables).
 * TeamGoals is the fact table aggregated by a native HANA SQL view
 * (see db/hana-views.cds + db/src/WORLDCUP_TEAM_STANDINGS.hdbview).
 */

entity Teams {
  key ID           : Integer;
      name         : String;
      grp          : String;   // group A..L
      confederation: String;   // UEFA, CONMEBOL, ...
      coach        : String;
      matchesHome  : Association to many Matches on matchesHome.homeTeam = $self;
      matchesAway  : Association to many Matches on matchesAway.awayTeam = $self;
}

entity Matches {
  key ID        : Integer;
      stage     : String;      // Group, Round of 16, Quarter-final, ...
      city      : String;
      matchDate : Date;
      homeTeam  : Association to Teams;
      awayTeam  : Association to Teams;
      homeGoals : Integer;
      awayGoals : Integer;
}

/**
 * Fact table: goals scored by a team in a single match.
 * Aggregated and ranked per STAGE in the native HANA SQL view
 * WORLDCUP_TEAM_STANDINGS (RANK() window function).
 */
entity TeamGoals {
  key ID    : Integer;
      team  : String;
      stage : String;
      goals : Integer;
}
