import cds from '@sap/cds';

// Runs on SQLite under `npm run test:sqlite`, on bound HANA under `npm test`.
const { GET, expect } = cds.test(__dirname + '/..');

describe('Players — Integration Tests', () => {
  it('serves players with their team', async () => {
    const { data } = await GET`/odata/v4/worldcup/Players?$filter=ID eq 1&$expand=team`;
    expect(data.value[0]).to.include({ name: 'Kylian Mbappé', position: 'Forward' });
    expect(data.value[0].team).to.include({ name: 'France' });
  });

  it('exact substring search still works everywhere', async () => {
    const { data } = await GET`/odata/v4/worldcup/Players?$search=Yamal`;
    expect(data.value).to.containSubset([{ name: 'Lamine Yamal' }]);
  });
  
});
