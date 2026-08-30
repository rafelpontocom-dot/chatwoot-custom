/**
 * Raevo — definição única do controle de formulário.
 *
 * A auditoria de produção encontrou 10 alturas de botão, 4 raios e 3 tratamentos
 * de campo convivendo no mesmo diálogo. A causa não é decisão errada: é a classe
 * copiada em cada tela. Enquanto ela viver colada no template, ela volta a divergir.
 *
 * Geometria conforme docs/raevo-design-system.md §4:
 * campo de uma linha é pílula; textarea usa `rounded-lg`. Altura única de 40 px.
 */

const BASE =
  'w-full border border-n-strong bg-n-surface-1 text-sm text-n-slate-12 ' +
  'outline-none transition-colors placeholder:text-n-slate-9 ' +
  'focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 ' +
  'disabled:cursor-not-allowed disabled:opacity-60';

/** input, e qualquer controle de uma linha */
export const RAEVO_CONTROL_CLASS = `h-10 rounded-full px-4 ${BASE}`;

/** select — mesma casca; o chevron é desenhado pelo RaevoField */
export const RAEVO_SELECT_CLASS = `h-10 appearance-none rounded-full px-4 pr-10 ${BASE}`;

/** textarea — não é pílula: várias linhas pedem canto de painel */
export const RAEVO_TEXTAREA_CLASS = `min-h-24 resize-y rounded-lg px-3 py-2.5 ${BASE}`;
