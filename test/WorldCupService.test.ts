import cds from '@sap/cds';

// Serve the CAP project. Under `npm run test:sqlite` this uses SQLite;
// under `npm test` (cds bind --exec --profile test) it uses the bound HANA.
const { GET, expect } = cds.test(__dirname + '/..');

describe('WorldCupService — baseline (runs on SQLite and HANA)', () => {
  it('serves Teams', async () => {
    const { data } = await GET`/odata/v4/worldcup/Teams`;
    expect(data.value).to.containSubset([{ ID: 1, name: 'Argentina', grp: 'A' }]);
  });

  it('serves Matches with scores', async () => {
    const { data } = await GET`/odata/v4/worldcup/Matches?$filter=ID eq 1`;
    expect(data.value[0]).to.include({ homeGoals: 2, awayGoals: 1 });
  });
});
