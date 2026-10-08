import { mount } from '@vue/test-utils';
import WhatsappGroupMentions from '../WhatsappGroupMentions.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const participants = [
  {
    id: '123456789012628@lid',
    name: 'Ana Souza',
    mention: '@123456789012628@lid',
  },
  { id: '5581999990000@c.us', name: 'Bruno', mention: '@5581999990000' },
];

const mountPicker = (props = {}) =>
  mount(WhatsappGroupMentions, {
    props: { participants, ...props },
    global: {
      stubs: {
        Avatar: true,
        CaretAnchoredPicker: {
          props: ['items'],
          emits: ['select'],
          template:
            '<ul><li v-for="item in items" :key="item.id" :data-id="item.id" @click="$emit(\'select\', item)">{{ item.label }} {{ item.subtitle }}</li></ul>',
        },
      },
    },
  });

describe('WhatsappGroupMentions', () => {
  it('offers everyone first, then whoever wrote in the group', () => {
    const items = mountPicker().findAll('li');

    expect(items.map(item => item.attributes('data-id'))).toEqual([
      'all',
      '123456789012628@lid',
      '5581999990000@c.us',
    ]);
    // O número mostrado é o que o WhatsApp vai ler: sem o sufixo @lid.
    expect(items[1].text()).toContain('@123456789012628');
    expect(items[1].text()).not.toContain('@lid');
  });

  it('inserts the text the WAHA turns into a mention', async () => {
    const wrapper = mountPicker();
    const items = wrapper.findAll('li');

    await items[0].trigger('click');
    await items[1].trigger('click');
    await items[2].trigger('click');

    expect(wrapper.emitted('select')).toEqual([
      ['@all'],
      ['@123456789012628@lid'],
      ['@5581999990000'],
    ]);
  });

  it('filters by name or by number', () => {
    expect(
      mountPicker({ searchKey: 'bru' })
        .findAll('li')
        .map(item => item.attributes('data-id'))
    ).toEqual(['5581999990000@c.us']);
    expect(
      mountPicker({ searchKey: '1234567' })
        .findAll('li')
        .map(item => item.attributes('data-id'))
    ).toEqual(['123456789012628@lid']);
  });
});
