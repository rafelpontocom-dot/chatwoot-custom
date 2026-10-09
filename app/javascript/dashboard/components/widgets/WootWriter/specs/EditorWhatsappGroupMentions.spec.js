// RAEVO (08/10, 123jpnbcb4w): contrato «conversation-reply-group-mentions».
// O @ numa resposta a um grupo de WhatsApp abre a lista de participantes e insere
// o texto que o WAHA transforma em menção. Se um upgrade do Editor perder isto,
// é este teste que falha.
import { flushPromises, mount } from '@vue/test-utils';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { nextTick } from 'vue';
import { createStore } from 'vuex';
import Editor from '../Editor.vue';
import WhatsappGroupMentions from '../../conversation/WhatsappGroupMentions.vue';
import TagAgents from '../../conversation/TagAgents.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));

let view = null;
vi.mock('@chatwoot/prosemirror-schema', async importOriginal => {
  const actual = await importOriginal();
  class TrackedEditorView extends actual.EditorView {
    constructor(...args) {
      super(...args);
      view = this;
    }
  }
  return { ...actual, EditorView: TrackedEditorView };
});

const zeroRect = { top: 0, bottom: 0, left: 0, right: 0, width: 0, height: 0 };
Range.prototype.getClientRects = () => [zeroRect];
Range.prototype.getBoundingClientRect = () => zeroRect;
Element.prototype.scrollIntoView = () => {};

const store = createStore({
  getters: {
    getUISettings: () => ({}),
    'globalConfig/get': () => ({}),
    'agents/getVerifiedAgents': () => [],
    'teams/getTeams': () => [],
    'accounts/isRTL': () => false,
    getCurrentAccountId: () => 1,
    'accounts/isFeatureEnabledonAccount': () => () => false,
    'accounts/getAccount': () => () => ({}),
  },
});

const participants = [
  {
    id: '987654321098765@lid',
    name: 'Carla Dias',
    mention: '@987654321098765@lid',
  },
];

let wrapper = null;
const mountEditor = props => {
  wrapper = mount(Editor, {
    props: {
      modelValue: '',
      whatsappGroupParticipants: participants,
      ...props,
    },
    global: {
      plugins: [store],
      stubs: { WhatsappGroupMentions: true, TagAgents: true },
    },
    attachTo: document.body,
  });
};
const type = async text => {
  view.dispatch(view.state.tr.insertText(text));
  await nextTick();
  await flushPromises();
};

afterEach(() => {
  wrapper?.unmount();
  view = null;
});

describe('Editor — @ in a WhatsApp group reply', () => {
  it('opens the participant list, not the agents, in a group reply', async () => {
    mountEditor({ whatsappGroup: true });
    await type('Bom dia @');

    expect(wrapper.findComponent(WhatsappGroupMentions).exists()).toBe(true);
    expect(wrapper.findComponent(TagAgents).exists()).toBe(false);
  });

  it('inserts the WAHA mention text when a participant is picked', async () => {
    mountEditor({ whatsappGroup: true });
    await type('Bom dia @');

    wrapper
      .findComponent(WhatsappGroupMentions)
      .vm.$emit('select', '@987654321098765@lid');
    await nextTick();

    expect(view.state.doc.textContent).toBe('Bom dia @987654321098765@lid ');
  });

  it('keeps the agents list in a private note of the same group', async () => {
    mountEditor({ whatsappGroup: true, isPrivate: true });
    await type('@');

    expect(wrapper.findComponent(WhatsappGroupMentions).exists()).toBe(false);
    expect(wrapper.findComponent(TagAgents).exists()).toBe(true);
  });

  it('shows no participant list outside a group', async () => {
    mountEditor({ whatsappGroup: false });
    await type('@');

    expect(wrapper.findComponent(WhatsappGroupMentions).exists()).toBe(false);
  });
});
