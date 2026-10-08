/**
 * A ORDEM das secções da coluna da direita da oportunidade.
 *
 * Mora aqui, e não dentro do diálogo, por duas razões. A primeira é que isto é
 * uma preferência GRAVADA: tem de sobreviver a uma secção que deixe de existir
 * numa versão futura, a uma chave repetida e a lixo gravado à mão — e uma lista
 * com uma chave que o produto não conhece desenharia uma secção vazia. A
 * segunda é que o diálogo tem mais de três mil linhas, onde uma regra destas
 * desaparece sem teste.
 */
export const DEFAULT_OPPORTUNITY_SECTION_ORDER = Object.freeze([
  'contact-details',
  'calendar',
  'finance',
  'forms',
  'timeline',
]);

const chaveDe = item => (typeof item === 'string' ? item : item?.name);

/**
 * Reconcilia a ordem gravada com as secções que o produto tem hoje.
 *
 * O que foi gravado manda na ordem; o que o produto ganhou depois entra no fim,
 * na ordem padrão. O que o produto já não tem é descartado.
 *
 * @param {Array<string|{name: string}>} [saved] valor vindo de `ui_settings`
 * @param {Array<string>} [known] secções que existem nesta versão
 * @returns {Array<string>} ordem utilizável
 */
export const resolveOpportunitySectionOrder = (
  saved,
  known = DEFAULT_OPPORTUNITY_SECTION_ORDER
) => {
  const conhecidas = [...known];
  const ordem = [];

  (Array.isArray(saved) ? saved : []).forEach(item => {
    const key = chaveDe(item);
    if (!conhecidas.includes(key) || ordem.includes(key)) return;

    ordem.push(key);
  });

  conhecidas.forEach(key => {
    if (!ordem.includes(key)) ordem.push(key);
  });

  return ordem;
};

/**
 * Troca uma secção com a vizinha VISÍVEL, não com a vizinha na lista completa.
 *
 * A diferença importa: com o Financeiro desligado, subir «Formulários» tem de o
 * pôr acima de «Agenda». Trocar com a vizinha da lista completa trocaria com uma
 * secção que ninguém vê, e o botão parecia não fazer nada.
 *
 * @param {Array<string>} order ordem completa, já reconciliada
 * @param {string} key secção a mover
 * @param {number} offset -1 para cima, 1 para baixo
 * @param {Array<string>} [visible] secções visíveis, na ordem em que aparecem
 * @returns {Array<string>} nova ordem completa
 */
export const moveOpportunitySection = (order, key, offset, visible = order) => {
  const atual = [...order];
  const visiveis = visible.filter(item => atual.includes(item));
  const indice = visiveis.indexOf(key);
  const vizinha = visiveis[indice + offset];

  if (indice === -1 || vizinha === undefined) return atual;

  const de = atual.indexOf(key);
  const para = atual.indexOf(vizinha);
  atual[de] = vizinha;
  atual[para] = key;

  return atual;
};
