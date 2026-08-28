import { flushPromises, mount } from '@vue/test-utils';
import PublicFormApp from '../PublicFormApp.vue';

const formPayload = {
  form: { name: 'Pré-consulta', locale: 'pt-BR', description: '' },
  schema: {
    sections: [
      {
        key: 'consulta',
        title: 'Consulta',
        fields: [
          {
            key: 'deseja_consulta',
            type: 'select',
            label: 'Deseja agendar uma consulta?',
            options: ['sim', 'nao'],
          },
          {
            key: 'melhor_horario',
            type: 'text',
            label: 'Melhor horário',
            visible_when: {
              field: 'deseja_consulta',
              operator: 'equals',
              value: 'sim',
            },
          },
        ],
      },
    ],
  },
};

describe('PublicFormApp', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('shows conditional fields only after their condition is met', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => formPayload })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(wrapper.find('#form-field-melhor_horario').exists()).toBe(false);

    await wrapper.find('#form-field-deseja_consulta').setValue('sim');

    expect(wrapper.find('#form-field-melhor_horario').exists()).toBe(true);
  });

  it('shows checkbox-dependent fields when consent is accepted', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          schema: {
            sections: [
              {
                key: 'consentimento',
                title: 'Consentimento',
                fields: [
                  {
                    key: 'aceite',
                    type: 'consent',
                    label: 'Aceito receber novidades',
                  },
                  {
                    key: 'canal',
                    type: 'select',
                    label: 'Canal preferido',
                    options: ['WhatsApp'],
                    visible_when: {
                      field: 'aceite',
                      operator: 'equals',
                      value: 'true',
                    },
                  },
                ],
              },
            ],
          },
        }),
      })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(wrapper.find('#form-field-canal').exists()).toBe(false);

    await wrapper.find('#form-field-aceite').setValue(true);

    expect(wrapper.find('#form-field-canal').exists()).toBe(true);
  });

  it('applies the approved public appearance and identifies the form brand', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          form: {
            ...formPayload.form,
            brand_name: 'Clínica Raevo',
            theme: 'warm',
          },
        }),
      })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(wrapper.get('[data-test="public-form-shell"]').classes()).toContain(
      'bg-n-amber-2'
    );
    expect(wrapper.get('[data-test="public-form-brand"]').text()).toContain(
      'Clínica Raevo'
    );
  });

  it('shows field guidance without replacing the visible question label', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          schema: {
            sections: [
              {
                ...formPayload.schema.sections[0],
                fields: [
                  {
                    ...formPayload.schema.sections[0].fields[0],
                    help_text:
                      'Informe o número com DDD para continuarmos pelo WhatsApp.',
                  },
                ],
              },
            ],
          },
        }),
      })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'Informe o número com DDD para continuarmos pelo WhatsApp.'
    );
  });

  it('prioritizes a section description over the general form description', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          form: {
            ...formPayload.form,
            description: 'Descrição geral do formulário.',
          },
          schema: {
            sections: [
              {
                ...formPayload.schema.sections[0],
                description: 'Conte-nos sua preferência antes da consulta.',
              },
            ],
          },
        }),
      })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'Conte-nos sua preferência antes da consulta.'
    );
    expect(wrapper.text()).not.toContain('Descrição geral do formulário.');
  });
});
