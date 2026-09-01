import { onBeforeUnmount, ref } from 'vue';

/**
 * Arrastar o quadro com o botão do meio, como num mapa.
 *
 * Num funil com sete etapas, chegar à última obrigava a descer até à barra de
 * rolagem, agarrá-la e puxar — um gesto que tira as mãos do trabalho e falha
 * quando a barra é fina. Segurar o botão do meio e arrastar mantém o gesto
 * onde o olhar já está.
 *
 * O botão do meio e não o esquerdo: o esquerdo pertence ao arrastar de cartões
 * entre etapas, e disputar esse gesto tornaria as duas coisas pouco fiáveis.
 */
export function usePanScroll() {
  const isPanning = ref(false);
  let alvo = null;
  let xInicial = 0;
  let scrollInicial = 0;

  const parar = () => {
    if (!isPanning.value) return;

    isPanning.value = false;
    alvo = null;
    document.body.style.removeProperty('cursor');
    document.body.style.removeProperty('user-select');
  };

  const aoMover = evento => {
    if (!isPanning.value || !alvo) return;

    alvo.scrollLeft = scrollInicial - (evento.clientX - xInicial);
  };

  const comecar = evento => {
    // 1 é o botão do meio. Qualquer outro segue o seu caminho normal.
    if (evento.button !== 1) return;

    alvo = evento.currentTarget;
    xInicial = evento.clientX;
    scrollInicial = alvo.scrollLeft;
    isPanning.value = true;
    // Sem isto o browser abre o seu próprio auto-scroll e o cursor fica preso.
    evento.preventDefault();
    document.body.style.cursor = 'grabbing';
    document.body.style.userSelect = 'none';

    window.addEventListener('mousemove', aoMover);
    window.addEventListener('mouseup', parar, { once: true });
    // Sair da janela a arrastar deixaria o cursor em «grabbing» para sempre.
    window.addEventListener('blur', parar, { once: true });
  };

  onBeforeUnmount(() => {
    parar();
    window.removeEventListener('mousemove', aoMover);
  });

  return { isPanning, startPan: comecar };
}
