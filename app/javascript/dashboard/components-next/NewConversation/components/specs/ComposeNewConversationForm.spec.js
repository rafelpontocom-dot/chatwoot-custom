// RAEVO (08/10, 123jpnbcb50): contrato «compose-also-send-via». Se um upgrade do
// formulário nativo perder o «Enviar também por», é este teste que falha.
import { shallowMount } from '@vue/test-utils';
import ComposeNewConversationForm from '../ComposeNewConversationForm.vue';
import ExtraInboxesSelector from '../ExtraInboxesSelector.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useCopilotReply', () => ({
  useCopilotReply: () => ({ reset: vi.fn(), isActive: { value: false } }),
}));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

const inbox = (id, name, channelType) => ({
  id,
  name,
  channelType,
  sourceId: `src-${id}`,
});
const contact = {
  id: 42,
  name: 'Paciente',
  contactInboxes: [
    inbox(2, 'ALYSSON', 'Channel::Api'),
    inbox(3, 'THIAGO', 'Channel::Api'),
    inbox(1, 'Site', 'Channel::WebWidget'),
  ],
};

const mountForm = targetInbox =>
  shallowMount(ComposeNewConversationForm, {
    props: {
      selectedContact: contact,
      targetInbox,
      currentUser: { id: 7 },
      formState: {
        message: '',
        subject: '',
        ccEmails: '',
        bccEmails: '',
        attachedFiles: [],
      },
      contactsUiFlags: { isFetchingInboxes: false },
      contactConversationsUiFlags: { isCreating: false },
    },
  });

describe('ComposeNewConversationForm — also send via', () => {
  it('offers the other inboxes of the same kind as the chosen one', () => {
    const selector = mountForm(
      inbox(2, 'ALYSSON', 'Channel::Api')
    ).findComponent(ExtraInboxesSelector);

    expect(selector.exists()).toBe(true);
    expect(selector.props('inboxes').map(item => item.id)).toEqual([3]);
  });

  it('offers nothing before an inbox is chosen', () => {
    expect(mountForm(null).findComponent(ExtraInboxesSelector).exists()).toBe(
      false
    );
  });
});
