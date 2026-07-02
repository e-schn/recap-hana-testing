// NO namespace on purpose: the entity's SQL name must exactly match the
// deployed HANA view object id (WORLDCUP_TEAM_STANDINGS).

/**
 * CDS projection over the native HANA SQL view `WORLDCUP_TEAM_STANDINGS`
 * (db/src/WORLDCUP_TEAM_STANDINGS.hdbview).
 *
 * The view ranks teams within each stage by total goals using the HANA
 * window function `RANK() OVER (PARTITION BY ... ORDER BY ...)`.
 *
 * `@cds.persistence.exists` tells the compiler the DB object already exists
 * (HDI deploys the .hdbview), so CAP does NOT create a table/view for it — it
 * just reads from it. This object only exists on SAP HANA, which is exactly
 * why it must be tested against HANA, not SQLite.
 */
@cds.persistence.exists
entity WORLDCUP_TEAM_STANDINGS {
  key TEAM          : String;
  key STAGE         : String;
      GOALS         : Integer;
      RANK_IN_STAGE : Integer;
}
