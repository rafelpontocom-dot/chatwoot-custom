/**
 * As opções de um campo que a etapa exige, nos três sítios que o pedem: criar no
 * funil, criar na conversa e mover com campos em falta.
 *
 * O booleano saía como `select` sem opção nenhuma — o servidor manda
 * `options: []` para booleanos —, e um campo obrigatório que não se consegue
 * preencher volta a fazer da criação um beco sem saída. Visto no browser na
 * noite de 07/10: só «Selecione um valor», e o botão de criar sempre recusado.
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

export const requiredFieldType = definition =>
  definition?.fieldType || definition?.field_type;

export const requiredFieldInputType = definition => {
  const tipo = requiredFieldType(definition);
  if (['integer', 'decimal', 'currency'].includes(tipo)) return 'number';
  if (tipo === 'date') return 'date';
  if (tipo === 'datetime') return 'datetime-local';
  if (tipo === 'url') return 'url';

  return 'text';
};

// Vazio é o que o servidor recusa: `false` é uma resposta, lista vazia não é.
export const isRequiredFieldEmpty = value =>
  value === undefined ||
  value === null ||
  value === '' ||
  (Array.isArray(value) && value.length === 0);

export const emptyRequiredFieldValue = definition =>
  requiredFieldType(definition) === 'multiselect' ? [] : '';

/**
 * Os campos que a etapa exige e que se sabem ANTES de ir ao servidor.
 *
 * Os campos só apareciam depois de uma recusa, com aviso vermelho, quando a
 * etapa já diz no cliente o que exige — «erro primeiro». Ficam de fora os
 * condicionais: dependem de outra resposta e, numa criação, quase sempre estão
 * escondidos. Se o servidor os exigir, chegam pela recusa e juntam-se a estes.
 *
 * @param {Array} definitions definições do funil, camelizadas ou não
 * @param {Number|String} stageId etapa de destino
 * @returns {Array}
 */
export const requiredFieldsForStage = (definitions, stageId) =>
  (definitions || []).filter(definition => {
    const etapas = definition.requiredStageIds || definition.required_stage_ids;
    const condicao = definition.condition || {};

    return (
      (etapas || []).map(Number).includes(Number(stageId)) &&
      !(condicao.fieldKey || condicao.field_key) &&
      requiredFieldType(definition) !== 'formula'
    );
  });

/**
 * Junta o que o servidor diz que falta ao que já está no formulário, sem apagar
 * o que a pessoa escreveu. Substituir tudo pela resposta perdia as respostas dos
 * campos que o cliente já tinha mostrado.
 *
 * @returns {{definitions: Array, values: Object}}
 */
export const mergeRequiredFields = (
  definitions,
  values,
  serverDefinitions,
  missingKeys
) => {
  const conhecidas = new Set(definitions.map(definition => definition.key));
  const novas = (serverDefinitions || []).filter(
    definition =>
      missingKeys.includes(definition.key) && !conhecidas.has(definition.key)
  );
  const todas = [...definitions, ...novas];

  return {
    definitions: todas,
    values: Object.fromEntries(
      todas.map(definition => [
        definition.key,
        values[definition.key] ?? emptyRequiredFieldValue(definition),
      ])
    ),
  };
};
