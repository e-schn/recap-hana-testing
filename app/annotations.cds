using { WorldCupService } from '../srv/worldcup-service';

////////////////////////////////////////////////////////////////////////////
// Teams — List Report + Object Page (Fiori Elements)
////////////////////////////////////////////////////////////////////////////
annotate WorldCupService.Teams with @(
  UI: {
    HeaderInfo: {
      $Type         : 'UI.HeaderInfoType',
      TypeName      : 'Team',
      TypeNamePlural: 'Teams',
      Title         : { Value: name },
      Description   : { Value: confederation }
    },
    SelectionFields: [ grp, confederation ],
    LineItem: [
      { Value: name,          Label: 'Team' },
      { Value: grp,           Label: 'Group' },
      { Value: confederation, Label: 'Confederation' },
      { Value: coach,         Label: 'Coach' }
    ],
    Facets: [
      { $Type: 'UI.ReferenceFacet', Label: 'Details', Target: '@UI.FieldGroup#Main' }
    ],
    FieldGroup #Main: {
      Data: [
        { Value: name },
        { Value: grp },
        { Value: confederation },
        { Value: coach }
      ]
    }
  }
) {
  name          @title: 'Team';
  grp           @title: 'Group';
  confederation @title: 'Confederation';
  coach         @title: 'Coach';
};

////////////////////////////////////////////////////////////////////////////
// Matches — List Report + Object Page (Fiori Elements)
////////////////////////////////////////////////////////////////////////////
annotate WorldCupService.Matches with @(
  UI: {
    HeaderInfo: {
      $Type         : 'UI.HeaderInfoType',
      TypeName      : 'Match',
      TypeNamePlural: 'Matches',
      Title         : { Value: stage },
      Description   : { Value: city }
    },
    SelectionFields: [ stage, city ],
    LineItem: [
      { Value: matchDate,      Label: 'Date' },
      { Value: stage,          Label: 'Stage' },
      { Value: city,           Label: 'City' },
      { Value: homeTeam.name,  Label: 'Home' },
      { Value: homeGoals,      Label: 'Home Goals' },
      { Value: awayGoals,      Label: 'Away Goals' },
      { Value: awayTeam.name,  Label: 'Away' }
    ],
    Facets: [
      { $Type: 'UI.ReferenceFacet', Label: 'Match', Target: '@UI.FieldGroup#Match' }
    ],
    FieldGroup #Match: {
      Data: [
        { Value: stage },
        { Value: city },
        { Value: matchDate },
        { Value: homeTeam.name, Label: 'Home' },
        { Value: homeGoals },
        { Value: awayGoals },
        { Value: awayTeam.name, Label: 'Away' }
      ]
    }
  }
) {
  stage     @title: 'Stage';
  city      @title: 'City';
  matchDate @title: 'Date';
  homeGoals @title: 'Home Goals';
  awayGoals @title: 'Away Goals';
};

////////////////////////////////////////////////////////////////////////////
// Players — List Report + Object Page (Fiori Elements)
////////////////////////////////////////////////////////////////////////////
annotate WorldCupService.Players with @(
  UI: {
    HeaderInfo: {
      $Type         : 'UI.HeaderInfoType',
      TypeName      : 'Player',
      TypeNamePlural: 'Players',
      Title         : { Value: name },
      Description   : { Value: position }
    },
    SelectionFields: [ position ],
    LineItem: [
      { Value: shirtNo,   Label: 'No.' },
      { Value: name,      Label: 'Player' },
      { Value: position,  Label: 'Position' },
      { Value: team.name, Label: 'Team' },
      { Value: birthDate, Label: 'Born' }
    ],
    Facets: [
      { $Type: 'UI.ReferenceFacet', Label: 'Details', Target: '@UI.FieldGroup#Main' }
    ],
    FieldGroup #Main: {
      Data: [
        { Value: name },
        { Value: position },
        { Value: shirtNo },
        { Value: birthDate },
        { Value: team.name, Label: 'Team' }
      ]
    }
  }
) {
  name      @title: 'Player';
  position  @title: 'Position';
  shirtNo   @title: 'No.';
  birthDate @title: 'Born';
};
