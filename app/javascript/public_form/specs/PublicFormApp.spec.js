import { flushPromises, mount as mountComponent } from '@vue/test-utils';
import PublicFormApp from '../PublicFormApp.vue';

const mountedWrappers = [];
const mount = (...args) => {
  const wrapper = mountComponent(...args);
  mountedWrappers.push(wrapper);
  return wrapper;
};

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
    mountedWrappers.splice(0).forEach(wrapper => wrapper.unmount());
    vi.useRealTimers();
    window.history.replaceState({}, '', '/formularios/teste');
    window.localStorage.clear();
    vi.unstubAllGlobals();
  });

  it('renders a private draft preview without fetching or submitting a response', async () => {
    window.history.replaceState({}, '', '/formularios/previsao/rascunho-123');
    window.localStorage.setItem(
      'raevo-form-preview:rascunho-123',
      JSON.stringify({
        expiresAt: Date.now() + 60_000,
        payload: formPayload,
      })
    );
    const fetch = vi.fn();
    vi.stubGlobal('fetch', fetch);

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(
      wrapper.get('[data-test="public-form-preview-notice"]').text()
    ).toContain('Prévia privada');
    expect(wrapper.text()).toContain('Pré-consulta');
    expect(fetch).not.toHaveBeenCalled();

    await wrapper.find('form').trigger('submit');

    expect(fetch).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('não envia respostas');
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

  it('restores an invitation draft without saving it again on initial load', async () => {
    window.history.replaceState({}, '', '/formularios/convites/token-123');
    const fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        ...formPayload,
        draft: {
          answers: { deseja_consulta: 'sim', melhor_horario: '10h' },
          current_section_index: 0,
        },
      }),
    });
    vi.stubGlobal('fetch', fetch);

    const wrapper = mount(PublicFormApp);
    await flushPromises();
    await new Promise(resolve => {
      window.setTimeout(resolve, 650);
    });

    expect(wrapper.get('#form-field-deseja_consulta').element.value).toBe(
      'sim'
    );
    expect(wrapper.get('#form-field-melhor_horario').element.value).toBe('10h');
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('saves invitation answers after the person pauses typing', async () => {
    window.history.replaceState({}, '', '/formularios/convites/token-123');
    vi.useFakeTimers();
    const fetch = vi
      .fn()
      .mockResolvedValueOnce({ ok: true, json: async () => formPayload })
      .mockResolvedValueOnce({ ok: true, json: async () => ({}) });
    vi.stubGlobal('fetch', fetch);

    const wrapper = mount(PublicFormApp);
    await flushPromises();
    await wrapper.find('#form-field-deseja_consulta').setValue('sim');
    await vi.advanceTimersByTimeAsync(600);

    expect(fetch).toHaveBeenLastCalledWith(
      '/formularios/convites/token-123/rascunho',
      expect.objectContaining({ method: 'PATCH' })
    );
    expect(JSON.parse(fetch.mock.calls[1][1].body)).toEqual({
      draft: {
        answers: { deseja_consulta: 'sim' },
        current_section_index: 0,
      },
    });
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

  it('renders safe content blocks and collapses a two-column group into one form', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          schema: {
            sections: [
              {
                key: 'consulta',
                title: 'Consulta',
                layout: 'two_columns',
                content_blocks: [
                  {
                    id: 'titulo',
                    type: 'heading',
                    content: 'Prepare sua consulta',
                  },
                  {
                    id: 'texto',
                    type: 'rich_text',
                    content: 'Separe alguns minutos para responder.',
                  },
                  {
                    id: 'imagem',
                    type: 'image',
                    url: 'https://assets.raevo.io/consulta.jpg',
                    alt: 'Consultório',
                    caption: 'Atendimento acolhedor',
                  },
                  { id: 'divisor', type: 'divider' },
                ],
                fields: [
                  { key: 'nome', type: 'text', label: 'Nome' },
                  { key: 'telefone', type: 'phone', label: 'WhatsApp' },
                ],
              },
            ],
          },
        }),
      })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(
      wrapper.get('[data-test="public-form-content-heading"]').text()
    ).toContain('Prepare sua consulta');
    expect(
      wrapper.get('[data-test="public-form-content-image"]').attributes('src')
    ).toBe('https://assets.raevo.io/consulta.jpg');
    expect(wrapper.get('[data-test="public-form-fields"]').classes()).toContain(
      'sm:grid-cols-2'
    );
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
            brand_logo_url: 'https://cdn.raevo.io/clinica.svg',
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
    expect(wrapper.get('img').attributes('src')).toBe(
      'https://cdn.raevo.io/clinica.svg'
    );
    expect(
      wrapper.get('[data-test="public-form-progress"] span').classes()
    ).toContain('bg-n-amber-9');
  });

  it('shows the configured privacy policy without exposing configuration details', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          form: {
            ...formPayload.form,
            privacy_policy_url: 'https://clinica.raevo.io/privacidade',
          },
        }),
      })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(
      wrapper.get('[data-test="public-form-privacy-policy"]').attributes('href')
    ).toBe('https://clinica.raevo.io/privacidade');
  });

  it('shows Turnstile only when the public form enables it', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          form: {
            ...formPayload.form,
            captcha_provider: 'turnstile',
            captcha_site_key: 'turnstile-public-key',
          },
        }),
      })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();

    expect(wrapper.find('[data-test="public-form-captcha"]').exists()).toBe(
      true
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

  it('uses Portuguese from Portugal in the public confirmation', async () => {
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            ...formPayload,
            form: { ...formPayload.form, locale: 'pt_PT' },
          }),
        })
        .mockResolvedValueOnce({ ok: true, json: async () => ({}) })
    );

    const wrapper = mount(PublicFormApp);
    await flushPromises();
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(wrapper.text()).toContain(
      'Recebemos as suas informações. A equipa dará continuidade ao atendimento.'
    );
  });

  it('renders only the long-text control for a textarea question', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          schema: {
            sections: [
              {
                key: 'detalhes',
                title: 'Detalhes',
                fields: [
                  {
                    key: 'observacoes',
                    type: 'textarea',
                    label: 'Observações',
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

    expect(wrapper.findAll('#form-field-observacoes')).toHaveLength(1);
    expect(wrapper.get('#form-field-observacoes').element.tagName).toBe(
      'TEXTAREA'
    );
  });

  it('renders a typed acceptance signature as a safe text control', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...formPayload,
          schema: {
            sections: [
              {
                key: 'aceite',
                title: 'Aceite',
                fields: [
                  {
                    key: 'assinatura_paciente',
                    type: 'signature',
                    label: 'Digite seu nome para confirmar',
                    required: true,
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

    expect(
      wrapper.get('#form-field-assinatura_paciente').attributes('type')
    ).toBe('text');
    expect(wrapper.text()).toContain('Digite seu nome para confirmar');
  });

  it('sends a clinical document as multipart data instead of exposing it in answers', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          ...formPayload,
          schema: {
            sections: [
              {
                key: 'documentos',
                title: 'Documentos',
                fields: [
                  {
                    key: 'exames',
                    type: 'attachment',
                    label: 'Envie seus exames recentes',
                    required: true,
                  },
                ],
              },
            ],
          },
        }),
      })
      .mockResolvedValueOnce({ ok: true, json: async () => ({}) });
    vi.stubGlobal('fetch', fetch);

    const wrapper = mount(PublicFormApp);
    await flushPromises();
    const fileInput = wrapper.get('#form-field-exames');
    const file = new File(['resultado'], 'exame.pdf', {
      type: 'application/pdf',
    });
    Object.defineProperty(fileInput.element, 'files', { value: [file] });
    await fileInput.trigger('change');
    await wrapper.get('form').trigger('submit');
    await flushPromises();

    const [, options] = fetch.mock.calls[1];
    expect(options.headers).toEqual({ Accept: 'application/json' });
    expect(options.body).toBeInstanceOf(FormData);
    expect(options.body.get('submission[attachments][exames][]').name).toBe(
      'exame.pdf'
    );
    expect(options.body.get('submission[answers][exames]')).toBeNull();
  });
});
