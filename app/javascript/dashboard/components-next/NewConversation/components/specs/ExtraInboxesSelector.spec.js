import { mount } from '@vue/test-utils';
import ExtraInboxesSelector from '../ExtraInboxesSelector.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const inboxes = [
  { id: 8, label: 'WhatsApp 2' },
  { id: 9, label: 'WhatsApp 3' },
];

describe('ExtraInboxesSelector', () => {
  it('turns an inbox on and off, saying so with more than colour', async () => {
    const wrapper = mount(ExtraInboxesSelector, {
      props: {
        inboxes,
        modelValue: [],
        'onUpdate:modelValue': value => wrapper.setProps({ modelValue: value }),
      },
    });
    const segunda = () => wrapper.find('[data-testid="compose-extra-inbox-8"]');

    expect(segunda().attributes('aria-pressed')).toBe('false');
    await segunda().trigger('click');
    expect(wrapper.props('modelValue')).toEqual([8]);
    expect(segunda().attributes('aria-pressed')).toBe('true');
    expect(segunda().find('.i-lucide-check').exists()).toBe(true);

    await segunda().trigger('click');
    expect(wrapper.props('modelValue')).toEqual([]);
  });
});
