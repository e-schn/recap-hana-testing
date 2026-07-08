import { defineShikiSetup } from '@slidev/types';

export default defineShikiSetup(() => {
  return {
    themes: {
      dark: 'night-owl',
      light: 'night-owl',
    },
    // 'cds' has no Shiki grammar; highlight it as TypeScript (close enough).
    langAlias: {
      cds: 'typescript',
    },
  };
});
