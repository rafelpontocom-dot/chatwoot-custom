import { isApple } from 'shared/helpers/platform';

// RAEVO (123jpnbcxpe) — os atalhos da conversa já existiam (Alt+E resolve, ⌘/Ctrl+
// Alt+E resolve e abre a seguinte, Alt+M abre pendente e adiar), mas só se
// sabiam abrindo a ajuda com ⌘/. Isto escreve-os como cada sistema os desenha,
// para os pôr na dica dos próprios botões.
export const shortcutKeys = () =>
  isApple()
    ? { resolve: '⌥E', resolveNext: '⌘⌥E', moreActions: '⌥M' }
    : { resolve: 'Alt+E', resolveNext: 'Ctrl+Alt+E', moreActions: 'Alt+M' };
