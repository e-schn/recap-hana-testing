import { Players } from '#cds-models/WorldCupService';
import cds from '@sap/cds';

export class WorldCupService extends cds.ApplicationService {
  override init() {
    this.after('each', Players, player => {
      if (!player?.position) return;
      player.position =
        player.position === 'Goalkeeper' ? `${player.position} 🧤`
        : player.position === 'Forward' ? `${player.position} ⚽`
        : player.position === 'Defender' ? `${player.position} 🛡️`
        : player.position === 'Midfielder' ? `${player.position} 🎯`
        : player.position;
    });
    return super.init();
  }
}
