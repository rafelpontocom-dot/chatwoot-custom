export const FORM_STARTERS = Object.freeze([
  'blank',
  'lead_capture',
  'pre_consultation',
  'clinical_intake',
]);

function translate(t, key) {
  const translations = {
    'FIELDS.NAME': () => t('FORMS.STARTERS.FIELDS.NAME'),
    'FIELDS.PHONE': () => t('FORMS.STARTERS.FIELDS.PHONE'),
    'FIELDS.EMAIL': () => t('FORMS.STARTERS.FIELDS.EMAIL'),
    'FIELDS.CONSENT': () => t('FORMS.STARTERS.FIELDS.CONSENT'),
    'LEAD_CAPTURE.SECTION': () => t('FORMS.STARTERS.LEAD_CAPTURE.SECTION'),
    'LEAD_CAPTURE.INTEREST': () => t('FORMS.STARTERS.LEAD_CAPTURE.INTEREST'),
    'PRE_CONSULTATION.IDENTIFICATION_SECTION': () =>
      t('FORMS.STARTERS.PRE_CONSULTATION.IDENTIFICATION_SECTION'),
    'PRE_CONSULTATION.SECTION': () =>
      t('FORMS.STARTERS.PRE_CONSULTATION.SECTION'),
    'PRE_CONSULTATION.REASON': () =>
      t('FORMS.STARTERS.PRE_CONSULTATION.REASON'),
    'PRE_CONSULTATION.PREFERRED_PERIOD': () =>
      t('FORMS.STARTERS.PRE_CONSULTATION.PREFERRED_PERIOD'),
    'PRE_CONSULTATION.MORNING': () =>
      t('FORMS.STARTERS.PRE_CONSULTATION.MORNING'),
    'PRE_CONSULTATION.AFTERNOON': () =>
      t('FORMS.STARTERS.PRE_CONSULTATION.AFTERNOON'),
    'PRE_CONSULTATION.EVENING': () =>
      t('FORMS.STARTERS.PRE_CONSULTATION.EVENING'),
    'CLINICAL_INTAKE.SECTION': () =>
      t('FORMS.STARTERS.CLINICAL_INTAKE.SECTION'),
    'CLINICAL_INTAKE.ALLERGIES': () =>
      t('FORMS.STARTERS.CLINICAL_INTAKE.ALLERGIES'),
    'CLINICAL_INTAKE.MEDICATIONS': () =>
      t('FORMS.STARTERS.CLINICAL_INTAKE.MEDICATIONS'),
    'CLINICAL_INTAKE.CONDITIONS': () =>
      t('FORMS.STARTERS.CLINICAL_INTAKE.CONDITIONS'),
    'CLINICAL_INTAKE.OBSERVATIONS': () =>
      t('FORMS.STARTERS.CLINICAL_INTAKE.OBSERVATIONS'),
    'CLINICAL_INTAKE.CONSENT': () =>
      t('FORMS.STARTERS.CLINICAL_INTAKE.CONSENT'),
  };

  return translations[key]();
}

const contactFields = t => [
  {
    key: 'nome',
    label: translate(t, 'FIELDS.NAME'),
    type: 'text',
    required: true,
    options: [],
  },
  {
    key: 'telefone',
    label: translate(t, 'FIELDS.PHONE'),
    type: 'phone',
    required: true,
    options: [],
  },
  {
    key: 'email',
    label: translate(t, 'FIELDS.EMAIL'),
    type: 'email',
    required: false,
    options: [],
  },
];

const contactMapping = {
  contact: {
    name: 'nome',
    phone_number: 'telefone',
    email: 'email',
  },
};

function consentField(t) {
  return {
    key: 'aceite_contato',
    label: translate(t, 'FIELDS.CONSENT'),
    type: 'consent',
    required: true,
    options: [],
  };
}

export function getFormStarterSchema(starter, t) {
  if (!FORM_STARTERS.includes(starter) || starter === 'blank') return null;

  if (starter === 'lead_capture') {
    return {
      crm_mapping: contactMapping,
      sections: [
        {
          key: 'identificacao',
          title: translate(t, 'LEAD_CAPTURE.SECTION'),
          fields: [
            ...contactFields(t),
            {
              key: 'interesse',
              label: translate(t, 'LEAD_CAPTURE.INTEREST'),
              type: 'textarea',
              required: false,
              options: [],
            },
            consentField(t),
          ],
        },
      ],
    };
  }

  if (starter === 'clinical_intake') {
    return {
      sections: [
        {
          key: 'informacoes_saude',
          title: translate(t, 'CLINICAL_INTAKE.SECTION'),
          fields: [
            {
              key: 'alergias',
              label: translate(t, 'CLINICAL_INTAKE.ALLERGIES'),
              type: 'textarea',
              required: true,
              options: [],
            },
            {
              key: 'medicamentos_em_uso',
              label: translate(t, 'CLINICAL_INTAKE.MEDICATIONS'),
              type: 'textarea',
              required: false,
              options: [],
            },
            {
              key: 'condicoes_relevantes',
              label: translate(t, 'CLINICAL_INTAKE.CONDITIONS'),
              type: 'textarea',
              required: false,
              options: [],
            },
            {
              key: 'observacoes',
              label: translate(t, 'CLINICAL_INTAKE.OBSERVATIONS'),
              type: 'textarea',
              required: false,
              options: [],
            },
            {
              key: 'consentimento_clinico',
              label: translate(t, 'CLINICAL_INTAKE.CONSENT'),
              type: 'consent',
              required: true,
              options: [],
            },
          ],
        },
      ],
    };
  }

  return {
    crm_mapping: contactMapping,
    sections: [
      {
        key: 'identificacao',
        title: translate(t, 'PRE_CONSULTATION.IDENTIFICATION_SECTION'),
        fields: contactFields(t),
      },
      {
        key: 'pre_consulta',
        title: translate(t, 'PRE_CONSULTATION.SECTION'),
        fields: [
          {
            key: 'motivo_consulta',
            label: translate(t, 'PRE_CONSULTATION.REASON'),
            type: 'textarea',
            required: true,
            options: [],
          },
          {
            key: 'melhor_periodo',
            label: translate(t, 'PRE_CONSULTATION.PREFERRED_PERIOD'),
            type: 'select',
            required: false,
            options: [
              translate(t, 'PRE_CONSULTATION.MORNING'),
              translate(t, 'PRE_CONSULTATION.AFTERNOON'),
              translate(t, 'PRE_CONSULTATION.EVENING'),
            ],
          },
          consentField(t),
        ],
      },
    ],
  };
}
