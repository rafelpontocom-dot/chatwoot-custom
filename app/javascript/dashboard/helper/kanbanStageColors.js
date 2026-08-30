/**
 * Raevo · Sereno — cores de etapa do funil.
 *
 * No Sereno a etapa NÃO é um cabeçalho chapado de cor com texto branco. É uma
 * barra fina no topo da coluna + um ponto ao lado do nome. A cor identifica,
 * não domina. Por isso cada opção expõe variantes em vez de uma classe só:
 *
 *   barClass   barra de 5px no topo da coluna
 *   dotClass   ponto ao lado do nome da etapa
 *   inkClass   cor do ícone da etapa
 *   softClass  fundo suave, para contagem e realce discreto
 *   swatchClass  amostra no seletor de cor (usada nas Configurações)
 *   headerClass  mantida por compatibilidade — é igual a swatchClass
 *
 * Todas as cores saem dos tokens `n-*`. Ver docs/raevo-design-system.md.
 */
// Etapa sem cor definida fica neutra — cinza não é categoria, é ausência.
export const DEFAULT_KANBAN_STAGE_COLOR = 'slate';

const STAGE_COLORS = {
  slate: {
    solid: 'bg-n-slate-9',
    ink: 'text-n-slate-11',
    soft: 'bg-n-slate-3',
  },
  blue: { solid: 'bg-n-blue-9', ink: 'text-n-blue-11', soft: 'bg-n-blue-3' },
  teal: { solid: 'bg-n-teal-9', ink: 'text-n-teal-11', soft: 'bg-n-teal-3' },
  green: { solid: 'bg-n-teal-9', ink: 'text-n-teal-11', soft: 'bg-n-teal-3' },
  amber: {
    solid: 'bg-n-amber-9',
    ink: 'text-n-amber-11',
    soft: 'bg-n-amber-3',
  },
  orange: {
    solid: 'bg-n-amber-9',
    ink: 'text-n-amber-11',
    soft: 'bg-n-amber-3',
  },
  ruby: { solid: 'bg-n-ruby-9', ink: 'text-n-ruby-11', soft: 'bg-n-ruby-3' },
  rose: { solid: 'bg-n-ruby-9', ink: 'text-n-ruby-11', soft: 'bg-n-ruby-3' },
  violet: {
    solid: 'bg-n-violet-9',
    ink: 'text-n-violet-11',
    soft: 'bg-n-violet-3',
  },
  iris: { solid: 'bg-n-iris-9', ink: 'text-n-iris-11', soft: 'bg-n-iris-3' },
};

export const KANBAN_STAGE_COLOR_OPTIONS = Object.keys(STAGE_COLORS).map(
  value => {
    const { solid, ink, soft } = STAGE_COLORS[value];
    return {
      value,
      barClass: solid,
      dotClass: solid,
      inkClass: ink,
      softClass: soft,
      swatchClass: solid,
      // Compatibilidade: chamadas antigas esperavam uma classe de fundo sólida.
      headerClass: solid,
    };
  }
);

export const getKanbanStageColorOption = color =>
  KANBAN_STAGE_COLOR_OPTIONS.find(option => option.value === color) ||
  KANBAN_STAGE_COLOR_OPTIONS.find(
    option => option.value === DEFAULT_KANBAN_STAGE_COLOR
  );

/**
 * Sequência de cores para etapas novas, na ordem da paleta validada:
 * azul → teal → âmbar → violeta. Repete a partir daí.
 *
 * Etapa nova nasce colorida em vez de cinza — a pessoa troca depois se quiser.
 * Decisão de 29/08/2026. Ver docs/raevo-design-system.md §2.
 */
export const AUTO_STAGE_COLOR_SEQUENCE = ['blue', 'teal', 'amber', 'violet'];

export const nextKanbanStageColor = (position = 0) =>
  AUTO_STAGE_COLOR_SEQUENCE[
    Math.abs(Number(position) || 0) % AUTO_STAGE_COLOR_SEQUENCE.length
  ];

export const getKanbanStageColorClass = color =>
  getKanbanStageColorOption(color).headerClass;
