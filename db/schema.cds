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
