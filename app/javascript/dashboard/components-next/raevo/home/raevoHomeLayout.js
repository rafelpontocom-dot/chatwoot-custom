/**
 * O Início editável — a geometria, sem Vue.
 *
 * Decisão de 18/10 (proposta A, «grelha livre»): cada pessoa arruma o seu Início
 * numa grelha de 12 colunas, move e redimensiona à vontade, e os blocos encaixam
 * sem se sobreporem. Tudo o que é regra de posição vive aqui, em funções puras,
 * para se testar sem montar componente nenhum.
 *
 * O que se grava é só isto: id, x, y, w, h e, se a pessoa renomeou, o título.
 * Rótulo, ícone, cor e dados nunca — vêm do código e do servidor, e um layout
 * gravado não pode ficar a mentir quando eles mudam.
 */

export const GRID_COLUMNS = 12;
export const LAYOUT_VERSION = 1;
export const MAX_TITLE_LENGTH = 60;
// Não há bloco que precise de mais: um a mais é dado corrompido, não escolha.
const MAX_ROW = 200;

// O mínimo de cada tipo é o tamanho abaixo do qual o conteúdo deixa de se ler:
// um indicador precisa do rótulo e do número; uma lista, do cabeçalho e de uma
// linha inteira.
const MIN_SIZE = Object.freeze({
  kpi: { w: 2, h: 2 },
  list: { w: 4, h: 3 },
});

export const HOME_WIDGETS = Object.freeze({
  'kpi-conversations': { kind: 'kpi' },
  'kpi-actions': { kind: 'kpi' },
  'kpi-agenda': { kind: 'kpi' },
  'kpi-payments': { kind: 'kpi' },
  'today-appointments': { kind: 'list' },
  'open-conversations': { kind: 'list' },
  'overdue-actions': { kind: 'list' },
  'overdue-payments': { kind: 'list' },
  'stale-opportunities': { kind: 'list' },
  // Os insights da entrega 2 (18/10): não estão no Início de origem, entram
  // pelo «+». Os ids espelham `Raevo::HomeInsights::KEYS`.
  'kpi-pipeline-value': { kind: 'kpi', insight: true },
  'kpi-close-rate': { kind: 'kpi', insight: true },
  'kpi-won-month': { kind: 'kpi', insight: true },
  'kpi-first-response': { kind: 'kpi', insight: true },
  'kpi-attendance': { kind: 'kpi', insight: true },
  'kpi-ai-opportunities': { kind: 'kpi', insight: true },
  'kpi-waiting-24h': { kind: 'kpi', insight: true },
});

export const INSIGHT_IDS = Object.keys(HOME_WIDGETS).filter(
  id => HOME_WIDGETS[id].insight
);

// O tamanho com que entra um bloco que não está no Início de origem: o de um
// indicador ou de uma lista da fila de hoje.
const ADD_SIZE = Object.freeze({ kpi: { w: 3, h: 2 }, list: { w: 6, h: 4 } });

// O Início de antes de 18/10, posto na grelha: quatro indicadores, a agenda a
// toda a largura, conversas à esquerda e larga, ações e cobranças à direita.
// Quem nunca mexeu vê o que já via.
export const DEFAULT_HOME_LAYOUT = Object.freeze([
  { id: 'kpi-conversations', x: 0, y: 0, w: 3, h: 2 },
  { id: 'kpi-actions', x: 3, y: 0, w: 3, h: 2 },
  { id: 'kpi-agenda', x: 6, y: 0, w: 3, h: 2 },
  { id: 'kpi-payments', x: 9, y: 0, w: 3, h: 2 },
  { id: 'today-appointments', x: 0, y: 2, w: 12, h: 3 },
  { id: 'open-conversations', x: 0, y: 5, w: 7, h: 7 },
  { id: 'overdue-actions', x: 7, y: 5, w: 5, h: 4 },
  { id: 'overdue-payments', x: 7, y: 9, w: 5, h: 3 },
  { id: 'stale-opportunities', x: 0, y: 12, w: 7, h: 4 },
]);

export const minSize = id => MIN_SIZE[HOME_WIDGETS[id].kind];

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);

export const clampItem = item => {
  const min = minSize(item.id);
  const w = clamp(item.w, min.w, GRID_COLUMNS);
  return {
    ...item,
    w,
    h: clamp(item.h, min.h, MAX_ROW),
    x: clamp(item.x, 0, GRID_COLUMNS - w),
    y: clamp(item.y, 0, MAX_ROW),
  };
};

const collides = (a, b) =>
  a.id !== b.id &&
  a.x < b.x + b.w &&
  b.x < a.x + a.w &&
  a.y < b.y + b.h &&
  b.y < a.y + a.h;

/**
 * Encaixa os blocos de cima para baixo, sem buracos verticais e sem
 * sobreposição. O bloco que a pessoa está a mexer (`pinnedId`) fica onde ela o
 * pôs; os outros sobem o que puderem e descem o que precisarem para lhe abrir
 * espaço. É a gravidade de uma grelha de painel: sem ela, mover um bloco
 * deixava um buraco, e cada buraco é uma decisão que ninguém tomou.
 */
export const compactLayout = (items, pinnedId = null) => {
  const ordered = [...items].sort((a, b) => {
    if (a.id === pinnedId) return -1;
    if (b.id === pinnedId) return 1;
    return a.y - b.y || a.x - b.x;
  });
  const placed = [];

  ordered.forEach(original => {
    const item = { ...original };
    if (item.id !== pinnedId) {
      while (
        item.y > 0 &&
        !placed.some(p => collides(p, { ...item, y: item.y - 1 }))
      ) {
        item.y -= 1;
      }
    }
    while (placed.some(p => collides(p, item))) item.y += 1;
    placed.push(item);
  });

  // A ordem devolvida é a de leitura: é a do DOM, logo a do Tab e a do
  // telemóvel, onde os blocos se empilham numa coluna.
  return placed.sort((a, b) => a.y - b.y || a.x - b.x);
};

const update = (items, id, change) =>
  compactLayout(
    items.map(item =>
      item.id === id ? clampItem({ ...item, ...change }) : item
    ),
    id
  );

export const moveItem = (items, id, { x, y }) => update(items, id, { x, y });
export const resizeItem = (items, id, { w, h }) => update(items, id, { w, h });
export const renameItem = (items, id, title) =>
  items.map(item => {
    if (item.id !== id) return item;
    const clean = String(title || '')
      .trim()
      .slice(0, MAX_TITLE_LENGTH);
    const { title: _old, ...rest } = item;
    return clean ? { ...rest, title: clean } : rest;
  });
export const removeItem = (items, id) =>
  compactLayout(items.filter(item => item.id !== id));

// Um bloco acrescentado entra no primeiro espaço livre onde caiba, lido de
// cima para baixo e da esquerda para a direita — os buracos que a grelha livre
// deixa são o primeiro sítio a encher. Sem espaço, vai para o fim. O tamanho é
// o que tinha no Início de origem, onde alguém já pensou nele; um insight, que
// não estava lá, entra com o tamanho do seu tipo.
export const addItem = (items, id) => {
  if (items.some(item => item.id === id)) return items;
  const origin =
    DEFAULT_HOME_LAYOUT.find(item => item.id === id) ||
    ADD_SIZE[HOME_WIDGETS[id].kind];
  const bottom = Math.max(0, ...items.map(item => item.y + item.h));
  const candidate = { id, w: origin.w, h: origin.h };
  for (let y = 0; y <= bottom; y += 1) {
    for (let x = 0; x <= GRID_COLUMNS - origin.w; x += 1) {
      const box = { ...candidate, x, y };
      if (!items.some(item => collides(item, box))) {
        return compactLayout([...items, clampItem(box)]);
      }
    }
  }
  return compactLayout([
    ...items,
    clampItem({ ...candidate, x: 0, y: bottom }),
  ]);
};

const isInteger = value => Number.isInteger(value);

/**
 * Aceita só a forma documentada. Um layout gravado por uma versão antiga, ou
 * mexido à mão, devolve `null` e o Início cai no padrão — melhor do que
 * desenhar meio layout.
 */
export const sanitizeLayout = raw => {
  if (!raw || raw.version !== LAYOUT_VERSION || !Array.isArray(raw.items)) {
    return null;
  }
  const seen = new Set();
  const items = [];
  const valid = raw.items.every(item => {
    if (!item || !HOME_WIDGETS[item.id] || seen.has(item.id)) return false;
    if (![item.x, item.y, item.w, item.h].every(isInteger)) return false;
    if (item.title !== undefined && typeof item.title !== 'string')
      return false;
    seen.add(item.id);
    const clean = clampItem({
      id: item.id,
      x: item.x,
      y: item.y,
      w: item.w,
      h: item.h,
    });
    items.push(
      item.title
        ? { ...clean, title: item.title.slice(0, MAX_TITLE_LENGTH) }
        : clean
    );
    return true;
  });
  return valid ? compactLayout(items) : null;
};

/**
 * Qual layout se desenha. Primeiro o da pessoa; se ela nunca arrumou o seu, o
 * da equipa, que um administrador definiu; se também não há, o de origem.
 *
 * O da equipa não passa por cima de quem já arrumou: decisão de 18/10. Quem
 * investiu tempo no seu Início não o perde porque outra pessoa mexeu no dela.
 */
export const resolveLayout = ({ user, account } = {}) =>
  sanitizeLayout(user) ||
  sanitizeLayout(account) ||
  DEFAULT_HOME_LAYOUT.map(item => ({ ...item }));

/**
 * O que se vê agora. Um bloco cujo módulo está desligado, ou que a pessoa não
 * tem permissão de ver, sai — e o espaço fecha. Não se apaga do layout: se o
 * acesso voltar, ele volta ao sítio onde estava.
 */
export const visibleLayout = (items, availableIds) =>
  compactLayout(items.filter(item => availableIds.includes(item.id)));

/**
 * O que se grava depois de editar: o que a pessoa arrumou, mais os blocos que
 * estavam escondidos por falta de módulo. Sem estes, desligar o Financeiro um
 * dia apagava o sítio das cobranças para sempre.
 */
export const layoutToSave = (edited, previous, availableIds) => ({
  version: LAYOUT_VERSION,
  items: [
    ...edited,
    ...previous.filter(
      item =>
        !availableIds.includes(item.id) &&
        !edited.some(other => other.id === item.id)
    ),
  ],
});
