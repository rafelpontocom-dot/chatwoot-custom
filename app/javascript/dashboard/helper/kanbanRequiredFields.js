/**
 * As opções de um campo que a etapa exige, nos três sítios que o pedem: criar no
 * funil, criar na conversa e mover com campos em falta.
 *
 * O booleano saía como `select` sem opção nenhuma — o servidor manda
 * `options: []` para booleanos —, e um campo obrigatório que não se consegue
 * preencher volta a fazer da criação um beco sem saída. Visto no browser a
 * 08/10: só «Selecione um valor», e o botão de criar sempre recusado.
 *
 * @param {Object} definition definição do campo, camelizada ou não
 * @param {Function} t tradução do vue-i18n
 * @returns {Array<{value: *, label: string}>}
 */
export const requiredFieldOptions = (definition, t) => {
  const tipo = definition?.fieldType || definition?.field_type;
  if (tipo === 'boolean') {
    return [
      { value: true, label: t('KANBAN.OPPORTUNITY_DETAILS.BOOLEAN_YES') },
      { value: false, label: t('KANBAN.OPPORTUNITY_DETAILS.BOOLEAN_NO') },
    ];
  }

  return (definition?.options || []).map(option => ({
    value: option,
    label: String(option),
  }));
};
