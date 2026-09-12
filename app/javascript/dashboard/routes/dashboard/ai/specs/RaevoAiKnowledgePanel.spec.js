import { flushPromises, shallowMount } from '@vue/test-utils';
import RaevoAiKnowledgePanel from '../RaevoAiKnowledgePanel.vue';
import RaevoAiAPI from 'dashboard/api/raevoAi';

vi.mock('dashboard/api/raevoAi', () => ({
  default: {
    getKnowledge: vi.fn(),
    saveKnowledgeDraft: vi.fn(),
    publishKnowledge: vi.fn(),
    rollbackKnowledge: vi.fn(),
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (chave, valores) =>
      valores ? `${chave}:${JSON.stringify(valores)}` : chave,
  }),
}));

const topics = [
  { key: 'precos', label: 'Preços', sensitive: true },
  { key: 'horarios', label: 'Horários', sensitive: false },
];
const item = {
  id: 'a1',
  topic_key: 'precos',
  title: 'Botox',
  content: 'A partir de X',
  commercial_profile: 'private',
};

const montar = (isAdmin = true) =>
  shallowMount(RaevoAiKnowledgePanel, {
    props: { isAdmin },
    global: {
      stubs: {
        RaevoField: {
          template:
            '<div><slot control-class="control" field-id="campo" /></div>',
        },
        NextButton: {
          emits: ['click'],
          template:
            '<button v-bind="$attrs" type="button" @click="$emit(\'click\')"><slot /></button>',
        },
      },
    },
  });

beforeEach(() => {
  vi.clearAllMocks();
  RaevoAiAPI.getKnowledge.mockResolvedValue({
    data: { topics, published: [item], draft: null, versions: [] },
  });
});

describe('RaevoAiKnowledgePanel', () => {
  it('shows one chip per subject, so an empty one is visible at a glance', async () => {
    // Um assunto vazio é o que faz a Elis não saber responder. A frase única
    // dizia «1 de 2»; a pastilha diz qual é o que falta.
    const wrapper = montar();
    await flushPromises();

    const pastilhas = wrapper.findAll('[data-testid="ai-knowledge-topic"]');
    expect(pastilhas).toHaveLength(2);
    expect(pastilhas[0].text()).toContain('1');
    expect(pastilhas[1].text()).toContain('—');
  });

  it('does not announce an unpublished draft when there is none', async () => {
    const wrapper = montar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="ai-knowledge-draft-pending"]').exists()
    ).toBe(false);
  });

  it('saving writes a draft and says nothing was published', async () => {
    // É a regra central do ecrã: editar não publica.
    RaevoAiAPI.saveKnowledgeDraft.mockResolvedValue({
      data: { draft: { revision: 1, items: [item] } },
    });
    const wrapper = montar();
    await flushPromises();

    await wrapper.find('[data-testid="ai-knowledge-add"]').trigger('click');
    await wrapper
      .find('[data-testid="ai-knowledge-save-draft"]')
      .trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.publishKnowledge).not.toHaveBeenCalled();
    expect(
      wrapper.find('[data-testid="ai-knowledge-notice"]').text()
    ).toContain('RAEVO_AI.KNOWLEDGE.SAVED');
    expect(
      wrapper.find('[data-testid="ai-knowledge-draft-pending"]').exists()
    ).toBe(true);
  });

  it('asks what to confirm instead of publishing a sensitive change silently', async () => {
    RaevoAiAPI.getKnowledge.mockResolvedValue({
      data: {
        topics,
        published: [],
        draft: { revision: 2, items: [item] },
        versions: [],
      },
    });
    RaevoAiAPI.publishKnowledge.mockRejectedValue({
      response: { status: 428, data: { topics: ['precos'] } },
    });
    const wrapper = montar();
    await flushPromises();

    await wrapper.find('[data-testid="ai-knowledge-publish"]').trigger('click');
    await flushPromises();

    const aviso = wrapper.find('[data-testid="ai-knowledge-sensitive"]');
    expect(aviso.exists()).toBe(true);
    expect(aviso.text()).toContain('Preços');
  });

  it('publishes once the clinic confirms the sensitive subject', async () => {
    RaevoAiAPI.getKnowledge.mockResolvedValue({
      data: {
        topics,
        published: [],
        draft: { revision: 2, items: [item] },
        versions: [],
      },
    });
    RaevoAiAPI.publishKnowledge
      .mockRejectedValueOnce({
        response: { status: 428, data: { topics: ['precos'] } },
      })
      .mockResolvedValueOnce({ data: { active_version: { id: 'v2' } } });
    const wrapper = montar();
    await flushPromises();

    await wrapper.find('[data-testid="ai-knowledge-publish"]').trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="ai-knowledge-sensitive-confirm"]')
      .trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.publishKnowledge).toHaveBeenLastCalledWith(
      expect.objectContaining({ confirmed_sensitive_keys: ['precos'] })
    );
  });

  it('asks the clinic to reload instead of overwriting someone else edit', async () => {
    RaevoAiAPI.saveKnowledgeDraft.mockRejectedValue({
      response: { status: 409 },
    });
    const wrapper = montar();
    await flushPromises();

    await wrapper.find('[data-testid="ai-knowledge-add"]').trigger('click');
    await wrapper
      .find('[data-testid="ai-knowledge-save-draft"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('RAEVO_AI.KNOWLEDGE.CONFLICT');
  });

  it('reports the bridge being down instead of showing an empty base', async () => {
    RaevoAiAPI.getKnowledge.mockRejectedValue(new Error('sem rede'));
    const wrapper = montar();
    await flushPromises();

    expect(wrapper.find('[data-testid="ai-knowledge-error"]').exists()).toBe(
      true
    );
  });

  it('does not offer editing to someone who only answers conversations', async () => {
    const wrapper = montar(false);
    await flushPromises();

    expect(wrapper.find('[data-testid="ai-knowledge-add"]').exists()).toBe(
      false
    );
  });

  it('does not restore a version without an explicit confirmation', async () => {
    // Repor apaga a base inteira: é a única ação do ecrã que pede confirmação.
    RaevoAiAPI.getKnowledge.mockResolvedValue({
      data: {
        topics,
        published: [item],
        draft: null,
        // Duas versões: a activa não oferece «Voltar», só as anteriores.
        versions: [
          { id: 'v2', version_number: 2, status: 'published', item_count: 4 },
          { id: 'v1', version_number: 1, status: 'published', item_count: 3 },
        ],
      },
    });
    const confirmar = vi.spyOn(window, 'confirm').mockReturnValue(false);
    const wrapper = montar();
    await flushPromises();

    await wrapper
      .find('[data-testid="ai-knowledge-versions"] button')
      .trigger('click');
    await flushPromises();

    expect(confirmar).toHaveBeenCalled();
    expect(RaevoAiAPI.rollbackKnowledge).not.toHaveBeenCalled();
    confirmar.mockRestore();
  });
});
