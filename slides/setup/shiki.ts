import { defineShikiSetup } from '@slidev/types';

export default defineShikiSetup(() => {
  return {
    themes: {
      dark: 'vitesse-dark',
      light: 'vitesse-light',
    },
    // 'cds' has no Shiki grammar; highlight it as TypeScript (close enough).
    langAlias: {
      cds: 'typescript',
    },
  };
});
