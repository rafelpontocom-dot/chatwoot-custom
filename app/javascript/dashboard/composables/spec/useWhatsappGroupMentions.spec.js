import { nextTick, ref } from 'vue';
import { flushPromises } from '@vue/test-utils';
import WhatsappGroupParticipantsAPI from 'dashboard/api/whatsappGroupParticipants';
import {
  isWhatsappGroupConversation,
  useWhatsappGroupMentions,
} from '../useWhatsappGroupMentions';

vi.mock('dashboard/api/whatsappGroupParticipants', () => ({
  default: { get: vi.fn() },
}));

const group = id => ({
  id,
  meta: { sender: { identifier: '120363012345678162@g.us' } },
});
const person = id => ({
  id,
  meta: { sender: { identifier: '5581999990000@c.us' } },
});

describe('useWhatsappGroupMentions', () => {
  beforeEach(() => {
    WhatsappGroupParticipantsAPI.get.mockReset();
  });

  it('recognises a WhatsApp group by the @g.us contact the WAHA creates', () => {
    expect(isWhatsappGroupConversation(group(1))).toBe(true);
    expect(isWhatsappGroupConversation(person(2))).toBe(false);
    expect(isWhatsappGroupConversation({})).toBe(false);
  });

  it('loads the participants of a group and nothing for a person', async () => {
    WhatsappGroupParticipantsAPI.get.mockResolvedValue({
      data: {
        payload: [{ id: '1@lid', name: 'Ana', mention: '@1@lid' }],
      },
    });
    const conversation = ref(person(2));
    const { isGroup, participants } = useWhatsappGroupMentions(conversation);
    await flushPromises();

    expect(isGroup.value).toBe(false);
    expect(WhatsappGroupParticipantsAPI.get).not.toHaveBeenCalled();

    conversation.value = group(7);
    await nextTick();
    await flushPromises();

    expect(isGroup.value).toBe(true);
    expect(WhatsappGroupParticipantsAPI.get).toHaveBeenCalledWith(7);
    expect(participants.value).toEqual([
      { id: '1@lid', name: 'Ana', mention: '@1@lid' },
    ]);
  });

  it('drops an answer that arrives after the agent moved to another group', async () => {
    let resolveFirst;
    WhatsappGroupParticipantsAPI.get
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveFirst = resolve;
          })
      )
      .mockResolvedValueOnce({ data: { payload: [] } });
    const conversation = ref(group(7));
    const { participants } = useWhatsappGroupMentions(conversation);

    conversation.value = group(8);
    await nextTick();
    await flushPromises();
    resolveFirst({
      data: { payload: [{ id: 'x', name: 'Do 7', mention: '@x' }] },
    });
    await flushPromises();

    expect(participants.value).toEqual([]);
  });
});
