import wootConstants from 'dashboard/constants/globals';

/**
 * Com que aba a lista de conversas abre.
 *
 * Abria sempre em «Minhas», mesmo para quem trabalha o dia inteiro noutra. O
 * estado e a ordenação já eram lembrados; a aba não era.
 *
 * O pedido tinha duas metades que parecem brigar — «lembra o último que usei» e
 * «deixa-me escolher o padrão». Não brigam se forem a mesma preferência: o
 * padrão é uma escolha, e «o último que usei» é um dos valores possíveis dessa
 * escolha. A regra fica aqui, fora do componente, porque é a parte que decide
 * o que a pessoa vê ao abrir o produto — e porque o componente não tem teste.
 */
export const LAST_USED_TAB = 'last_used';

const isAssigneeTab = value =>
  Object.values(wootConstants.ASSIGNEE_TYPE).includes(value);

export const resolveAssigneeTab = ({ preferred, lastUsed } = {}) => {
  // Preferência fixa ganha sempre: foi escolhida de propósito.
  if (isAssigneeTab(preferred)) return preferred;
  // Sem preferência fixa, vale o que ficou da última vez.
  if (isAssigneeTab(lastUsed)) return lastUsed;
  // Sem nada, continua como era antes. Ninguém é surpreendido na primeira vez.
  return wootConstants.ASSIGNEE_TYPE.ME;
};

/**
 * Qual filtro guardado abre o painel de Conversas.
 *
 * Decide-se aqui, fora da rota, pela mesma razão que a aba: é o que a pessoa vê
 * ao entrar no produto, e uma rota não tem onde ser testada.
 *
 * Só vale à entrada. Quem já está dentro e clica noutro sítio da barra lateral
 * vai para onde clicou — o filtro padrão é por onde se começa, não uma prisão.
 */
export const defaultFolderOnEntry = ({ fromName, folderId } = {}) => {
  if (fromName) return null;
  const id = Number(folderId);
  return Number.isInteger(id) && id > 0 ? id : null;
};
