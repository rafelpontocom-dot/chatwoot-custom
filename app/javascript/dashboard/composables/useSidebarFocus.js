import { ref, readonly, onBeforeUnmount } from 'vue';

/**
 * Modo de foco: recolhe a navegação do CRM a ícones enquanto uma tela precisa
 * da largura toda — hoje, o construtor de formulários.
 *
 * Recolher não é a mesma coisa que esconder. Esconder por completo daria mais
 * 56px, mas tiraria à secretária o acesso de um clique a Conversas e Pipeline
 * no meio de montar uma anamnese. A ícones, os módulos continuam todos lá.
 *
 * Deliberadamente fora de `useUISettings`: isto é um estado de momento, não uma
 * preferência. Guardar a largura recolhida faria a barra do utilizador ficar
 * pequena para sempre só porque ele abriu um editor uma vez.
 */
const isFocused = ref(false);

export function useSidebarFocus() {
  return { isSidebarFocused: readonly(isFocused) };
}

/** Para quem pede o foco: solta-o sozinho ao sair da tela. */
export function useRequestSidebarFocus() {
  const setSidebarFocus = value => {
    isFocused.value = Boolean(value);
  };

  // Sair do editor pelo botão «voltar», pelo menu ou pelo atalho do browser
  // tem de devolver a barra. Confiar em cada saída lembrar-se disso não dura.
  onBeforeUnmount(() => {
    isFocused.value = false;
  });

  return { setSidebarFocus };
}
