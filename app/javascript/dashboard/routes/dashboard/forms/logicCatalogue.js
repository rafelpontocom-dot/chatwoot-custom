/**
 * Espelho de `Forms::Logic` (app/services/forms/logic.rb).
 *
 * A interface precisa de saber que operadores oferecer sem ir ao servidor a
 * cada seleção de pergunta, e o servidor precisa de recusar o que não conhece.
 * Isso obriga a tabela a existir dos dois lados — e uma tabela em dois sítios
 * diverge sozinha.
 *
 * A defesa é `spec/services/forms/logic_catalogue_parity_spec.rb`: ele lê este
 * ficheiro e falha se uma lista aqui deixar de bater com a do Ruby. Ao mexer
 * numa, mexa na outra; o teste diz qual esqueceu.
 */
const COMMON_OPERATORS = ['is_empty', 'is_not_empty'];

const TEXT_OPERATORS = [
  'is',
  'is_not',
  'contains',
  'does_not_contain',
  'starts_with',
  'ends_with',
];
const SINGLE_CHOICE_OPERATORS = ['is', 'is_not'];
const MULTIPLE_CHOICE_OPERATORS = [
  'is',
  'is_not',
  'contains',
  'does_not_contain',
];
const NUMBER_OPERATORS = [
  'equal',
  'not_equal',
  'greater_than',
  'greater_or_equal_than',
  'less_or_equal_than',
];
const DATE_OPERATORS = ['is', 'is_not', 'is_before', 'is_after'];

export const OPERATORS_BY_TYPE = {
  text: TEXT_OPERATORS,
  textarea: TEXT_OPERATORS,
  email: TEXT_OPERATORS,
  phone: TEXT_OPERATORS,
  number: NUMBER_OPERATORS,
  currency: NUMBER_OPERATORS,
  date: DATE_OPERATORS,
  datetime: DATE_OPERATORS,
  select: SINGLE_CHOICE_OPERATORS,
  checkbox: SINGLE_CHOICE_OPERATORS,
  consent: SINGLE_CHOICE_OPERATORS,
  multi_select: MULTIPLE_CHOICE_OPERATORS,
};

export const ACTIONS = ['navigate', 'calculate'];
export const CALCULATE_OPERATORS = [
  'addition',
  'subtraction',
  'multiplication',
  'division',
  'assignment',
];
export const VARIABLE_KINDS = ['number', 'text'];

/**
 * Assinatura, anexo e campo oculto ficam só com os comuns: não há «contém»
 * útil numa assinatura.
 */
export const operatorsFor = fieldType => [
  ...(OPERATORS_BY_TYPE[fieldType] || []),
  ...COMMON_OPERATORS,
];

/** Operadores que não precisam de valor: perguntam só se foi respondida. */
export const isUnaryOperator = operator => COMMON_OPERATORS.includes(operator);
