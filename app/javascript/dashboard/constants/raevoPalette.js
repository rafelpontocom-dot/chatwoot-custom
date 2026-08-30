/**
 * Raevo — paleta de dados.
 *
 * Cores que o usuário escolhe e que ficam GRAVADAS NO BANCO: etapa do funil,
 * procedimento da agenda, etiqueta. Só existem aqui porque viram dado, não CSS.
 *
 * Para cor de interface use os tokens (`n-*`, `--raevo-*`), nunca este arquivo.
 * Ver docs/raevo-design-system.md.
 *
 * Validada para daltonismo — pior par ΔE 9,7 em deuteranopia:
 *   node scripts/validate_palette.js "#2563EB,#0F9D8F,#B45309,#A21CAF" --mode light --pairs all
 * Não acrescente nem troque cor sem rodar o validador.
 */

/** Etapas do funil, na ordem em que devem ser atribuídas. */
export const RAEVO_STAGE_COLORS = [
  '#2563EB', // azul
  '#0F9D8F', // teal
  '#B45309', // âmbar-terra
  '#A21CAF', // magenta
];

/** Etapa terminal (ganho/perdido): sem matiz, porque fim de trilha não é categoria. */
export const RAEVO_TERMINAL_COLOR = '#98A0AE';

/** Paleta oferecida ao usuário para procedimento e etiqueta. */
export const RAEVO_PICKER_COLORS = [
  ...RAEVO_STAGE_COLORS,
  '#0B6B4B', // verde escuro
  '#B42318', // vermelho
  '#1D4FD7', // azul escuro
  RAEVO_TERMINAL_COLOR,
];

/** Padrão de um procedimento novo. */
export const RAEVO_DEFAULT_PROCEDURE_COLOR = RAEVO_STAGE_COLORS[0];

/** Cor da etapa por índice, com a terminal no fim. */
export function stageColor(index, total) {
  if (total && index === total - 1) return RAEVO_TERMINAL_COLOR;
  return RAEVO_STAGE_COLORS[index % RAEVO_STAGE_COLORS.length];
}
