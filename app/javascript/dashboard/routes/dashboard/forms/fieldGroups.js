export const FORM_FIELD_GROUPS = Object.freeze([
  'contact',
  'appointment',
  'commercial',
]);

function translate(t, key) {
  const translations = {
    'CONTACT.TITLE': () => t('FORMS.FIELD_GROUPS.CONTACT.TITLE'),
    'CONTACT.DESCRIPTION': () => t('FORMS.FIELD_GROUPS.CONTACT.DESCRIPTION'),
    'CONTACT.NAME': () => t('FORMS.FIELD_GROUPS.CONTACT.NAME'),
    'CONTACT.PHONE': () => t('FORMS.FIELD_GROUPS.CONTACT.PHONE'),
    'CONTACT.EMAIL': () => t('FORMS.FIELD_GROUPS.CONTACT.EMAIL'),
    'APPOINTMENT.TITLE': () => t('FORMS.FIELD_GROUPS.APPOINTMENT.TITLE'),
    'APPOINTMENT.DESCRIPTION': () =>
      t('FORMS.FIELD_GROUPS.APPOINTMENT.DESCRIPTION'),
    'APPOINTMENT.DATE': () => t('FORMS.FIELD_GROUPS.APPOINTMENT.DATE'),
    'APPOINTMENT.PERIOD': () => t('FORMS.FIELD_GROUPS.APPOINTMENT.PERIOD'),
    'APPOINTMENT.MORNING': () => t('FORMS.FIELD_GROUPS.APPOINTMENT.MORNING'),
    'APPOINTMENT.AFTERNOON': () =>
      t('FORMS.FIELD_GROUPS.APPOINTMENT.AFTERNOON'),
    'APPOINTMENT.EVENING': () => t('FORMS.FIELD_GROUPS.APPOINTMENT.EVENING'),
    'COMMERCIAL.TITLE': () => t('FORMS.FIELD_GROUPS.COMMERCIAL.TITLE'),
    'COMMERCIAL.DESCRIPTION': () =>
      t('FORMS.FIELD_GROUPS.COMMERCIAL.DESCRIPTION'),
    'COMMERCIAL.ORIGIN': () => t('FORMS.FIELD_GROUPS.COMMERCIAL.ORIGIN'),
    'COMMERCIAL.GOOGLE': () => t('FORMS.FIELD_GROUPS.COMMERCIAL.GOOGLE'),
    'COMMERCIAL.INSTAGRAM': () => t('FORMS.FIELD_GROUPS.COMMERCIAL.INSTAGRAM'),
    'COMMERCIAL.REFERRAL': () => t('FORMS.FIELD_GROUPS.COMMERCIAL.REFERRAL'),
    'COMMERCIAL.INTEREST': () => t('FORMS.FIELD_GROUPS.COMMERCIAL.INTEREST'),
  };

  return translations[key]();
}

function field(attributes) {
  return {
    helpText: '',
    required: false,
    options: [],
    contactTarget: '',
    customAttribute: '',
    opportunityTarget: '',
    visibleWhenField: '',
    visibleWhenValue: '',
    ...attributes,
  };
}

export function getFormFieldGroup(group, t) {
  if (!FORM_FIELD_GROUPS.includes(group)) return null;

  if (group === 'contact') {
    return {
      key: 'contato',
      title: translate(t, 'CONTACT.TITLE'),
      description: translate(t, 'CONTACT.DESCRIPTION'),
      fields: [
        field({
          key: 'nome',
          label: translate(t, 'CONTACT.NAME'),
          type: 'text',
          required: true,
          contactTarget: 'name',
        }),
        field({
          key: 'telefone',
          label: translate(t, 'CONTACT.PHONE'),
          type: 'phone',
          required: true,
          contactTarget: 'phone_number',
        }),
        field({
          key: 'email',
          label: translate(t, 'CONTACT.EMAIL'),
          type: 'email',
          contactTarget: 'email',
        }),
      ],
    };
  }

  if (group === 'appointment') {
    return {
      key: 'preferencia_agenda',
      title: translate(t, 'APPOINTMENT.TITLE'),
      description: translate(t, 'APPOINTMENT.DESCRIPTION'),
      fields: [
        field({
          key: 'data_preferida',
          label: translate(t, 'APPOINTMENT.DATE'),
          type: 'date',
        }),
        field({
          key: 'periodo_preferido',
          label: translate(t, 'APPOINTMENT.PERIOD'),
          type: 'select',
          options: [
            translate(t, 'APPOINTMENT.MORNING'),
            translate(t, 'APPOINTMENT.AFTERNOON'),
            translate(t, 'APPOINTMENT.EVENING'),
          ],
        }),
      ],
    };
  }

  return {
    key: 'origem_interesse',
    title: translate(t, 'COMMERCIAL.TITLE'),
    description: translate(t, 'COMMERCIAL.DESCRIPTION'),
    fields: [
      field({
        key: 'origem',
        label: translate(t, 'COMMERCIAL.ORIGIN'),
        type: 'select',
        options: [
          translate(t, 'COMMERCIAL.GOOGLE'),
          translate(t, 'COMMERCIAL.INSTAGRAM'),
          translate(t, 'COMMERCIAL.REFERRAL'),
        ],
      }),
      field({
        key: 'interesse',
        label: translate(t, 'COMMERCIAL.INTEREST'),
        type: 'textarea',
      }),
    ],
  };
}
