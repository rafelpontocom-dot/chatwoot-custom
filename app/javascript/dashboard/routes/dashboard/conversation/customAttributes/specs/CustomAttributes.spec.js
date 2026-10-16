// RAEVO (08/10, 123jpnbcb5e): contrato «conversation-contact-attributes».
// O painel da conversa desenhava «WhatsApp JID/LID/Chat ID» em «Atributos do
// contato» depois de a ficha do contato e a da oportunidade já os esconderem.
import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import CustomAttributes from '../CustomAttributes.vue';

vi.mock('vue-router', () => ({ useRoute: () => ({ params: {} }) }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: {} },
    updateUISettings: vi.fn(),
  }),
}));

const definitions = [
  {
    attribute_key: 'data_nascimento',
    attribute_display_name: 'Data de nascimento',
    attribute_display_type: 'date',
  },
  {
    attribute_key: 'waha_whatsapp_jid',
    attribute_display_name: 'WhatsApp JID',
    attribute_display_type: 'text',
  },
  {
    attribute_key: 'waha_whatsapp_lid',
    attribute_display_name: 'WhatsApp LID',
    attribute_display_type: 'text',
  },
  {
    attribute_key: 'waha_whatsapp_chat_id',
    attribute_display_name: 'WhatsApp Chat ID',
    attribute_display_type: 'text',
  },
];

const store = createStore({
  getters: {
    getSelectedChat: () => ({
      id: 1,
      meta: { sender: { id: 2 } },
      custom_attributes: {},
    }),
    'attributes/getAttributesByModel': () => () => definitions,
    'contacts/getContact': () => () => ({
      id: 2,
      custom_attributes: {
        waha_whatsapp_jid: '5581999990000@s.whatsapp.net',
        waha_whatsapp_lid: '1@lid',
      },
    }),
  },
});

describe('CustomAttributes in the conversation panel', () => {
  it('shows the contact attributes without the WAHA addressing ones', () => {
    const wrapper = shallowMount(CustomAttributes, {
      props: {
        attributeType: 'contact_attribute',
        attributeFrom: 'conversation_contact_panel',
      },
      global: {
        plugins: [store],
        mocks: { $t: key => key },
        stubs: {
          Draggable: {
            props: ['list'],
            template:
              '<div><slot v-for="element in list" name="item" :element="element" /></div>',
          },
        },
      },
    });

    const labels = wrapper
      .findAllComponents({ name: 'CustomAttribute' })
      .map(attribute => attribute.props('label'));

    expect(labels).toContain('Data de nascimento');
    expect(labels.filter(label => /WhatsApp/.test(label))).toEqual([]);
  });
});
