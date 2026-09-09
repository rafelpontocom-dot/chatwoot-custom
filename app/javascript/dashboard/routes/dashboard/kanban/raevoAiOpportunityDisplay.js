export const RAEVO_AI_FIELD_LABEL_KEYS = {
  raevo_ai_summary: 'RAEVO_AI.OPPORTUNITY.FIELDS.SUMMARY',
  raevo_ai_status: 'RAEVO_AI.OPPORTUNITY.FIELDS.STATUS',
  raevo_ai_next_action: 'RAEVO_AI.OPPORTUNITY.FIELDS.NEXT_ACTION',
  raevo_ai_handoff_reason: 'RAEVO_AI.OPPORTUNITY.FIELDS.HANDOFF_REASON',
  raevo_ai_service_interest: 'RAEVO_AI.OPPORTUNITY.FIELDS.SERVICE_INTEREST',
  raevo_ai_scheduling_preference:
    'RAEVO_AI.OPPORTUNITY.FIELDS.SCHEDULING_PREFERENCE',
  raevo_ai_last_action_at: 'RAEVO_AI.OPPORTUNITY.FIELDS.LAST_ACTION_AT',
  raevo_ai_booking_status: 'RAEVO_AI.OPPORTUNITY.FIELDS.BOOKING_STATUS',
  raevo_ai_payment_status: 'RAEVO_AI.OPPORTUNITY.FIELDS.PAYMENT_STATUS',
};

export const humanizeRaevoAiValue = value =>
  String(value || '')
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());

export const displayRaevoAiFieldLabel = (t, field) => {
  const key = RAEVO_AI_FIELD_LABEL_KEYS[field?.key];
  return key ? t(key) : field?.label || humanizeRaevoAiValue(field?.key);
};

export const displayRaevoAiEnumValue = (t, value) => {
  const normalized = String(value || '').trim();
  if (!normalized) return '';

  const key = `RAEVO_AI.OPPORTUNITY.VALUES.${normalized.toUpperCase()}`;
  const translated = t(key);
  return translated === key ? humanizeRaevoAiValue(normalized) : translated;
};

export const displayRaevoAiSummary = (t, value) => {
  const normalized = String(value || '').trim();
  if (!normalized.startsWith('journey.')) return normalized;

  const phase = normalized.slice('journey.'.length).toUpperCase();
  const key = `RAEVO_AI.OPPORTUNITY.JOURNEY.${phase}`;
  const translated = t(key);
  return translated === key ? normalized : translated;
};

export const displayRaevoAiFieldValue = ({
  t,
  locale,
  field,
  value,
  emptyValue = '',
}) => {
  if (value === null || value === undefined || String(value).trim() === '') {
    return emptyValue;
  }

  if (field?.key === 'raevo_ai_summary') {
    return displayRaevoAiSummary(t, value);
  }

  const fieldType = field?.fieldType || field?.field_type;
  if (fieldType === 'datetime') {
    const date = new Date(value);
    if (!Number.isNaN(date.getTime())) {
      return new Intl.DateTimeFormat(String(locale || 'en').replace('_', '-'), {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(date);
    }
  }

  return Array.isArray(value)
    ? value.map(item => displayRaevoAiEnumValue(t, item)).join(', ')
    : displayRaevoAiEnumValue(t, value);
};
