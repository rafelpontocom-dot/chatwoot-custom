import { shallowMount } from '@vue/test-utils';
import { computed, ref } from 'vue';
import ContactCustomAttributes from '../ContactCustomAttributes.vue';

const atributos = ref([]);

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name => {
    if (name === 'attributes/getContactAttributes')
      return computed(() => atributos.value);
    return computed(() => []);
  },
}));

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings: ref({}) }),
}));

const atributo = (attributeKey, attributeDisplayName) => ({
  id: attributeKey,
  attributeKey,
  attributeDisplayName,
});

const montar = customAttributes =>
  shallowMount(ContactCustomAttributes, {
    props: { selectedContact: { customAttributes } },
    global: { stubs: { ContactCustomAttributeItem: true } },
  });

describe('ContactCustomAttributes', () => {
  beforeEach(() => {
    atributos.value = [
      atributo('date_of_birth', 'Data de nascimento'),
      atributo('waha_whatsapp_chat_id', 'WhatsApp Chat ID'),
      atributo('waha_whatsapp_jid', 'WhatsApp JID'),
      atributo('waha_whatsapp_lid', 'WhatsApp LID'),
    ];
  });

  // Conferido em produção: as contas 1 e 3 têm exatamente estas três chaves,
  // criadas pela integração do WAHA. São endereçamento interno do WhatsApp, não
  // dado de quem atende, e enchiam a ficha empurrando o resto para baixo.
  it('leaves the WhatsApp addressing attributes out of the contact sheet', () => {
    const wrapper = montar({
      date_of_birth: '1990-01-01',
      waha_whatsapp_chat_id: '55819@c.us',
      waha_whatsapp_jid: '55819@s.whatsapp.net',
      waha_whatsapp_lid: '123@lid',
    });

    const chaves = wrapper.vm.usedAttributes.map(a => a.attributeKey);
    expect(chaves).toEqual(['date_of_birth']);
  });

  it('hides them from the unused list too, not only from the filled one', () => {
    const wrapper = montar({});

    const chaves = wrapper.vm.unusedAttributes.map(a => a.attributeKey);
    expect(chaves).toEqual(['date_of_birth']);
  });

  // Se a conta só tiver atributos técnicos, a secção inteira não deve aparecer
  // a dizer que há atributos.
  it('reports no attributes at all when only the technical ones exist', () => {
    atributos.value = [atributo('waha_whatsapp_jid', 'WhatsApp JID')];
    const wrapper = montar({ waha_whatsapp_jid: 'x' });

    expect(wrapper.find('div').exists()).toBe(false);
  });
});
