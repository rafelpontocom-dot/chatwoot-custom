import { mount } from '@vue/test-utils';
import { computed } from 'vue';
import KanbanContactFieldManager from '../KanbanContactFieldManager.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () =>
    computed(() => () => [
      {
        attribute_key: 'waha_whatsapp_jid',
        attribute_display_name: 'WAHA JID',
      },
      { attribute_key: 'cpf', attribute_display_name: 'CPF' },
      { attribute_key: 'date_of_birth', attribute_display_name: 'Nascimento' },
    ]),
}));

describe('KanbanContactFieldManager', () => {
  it('reorders visible fields without swapping an invisible integration key', async () => {
    const wrapper = mount(KanbanContactFieldManager, {
      props: { modelValue: ['waha_whatsapp_jid', 'cpf', 'date_of_birth'] },
      global: {
        stubs: {
          NextButton: {
            props: ['disabled'],
            template: '<button :disabled="disabled" />',
          },
        },
      },
    });
    try {
      expect(
        wrapper
          .find('[data-testid="kanban-contact-field-waha_whatsapp_jid"]')
          .exists()
      ).toBe(false);
      await wrapper
        .find(
          '[data-testid="kanban-contact-field-date_of_birth"] [aria-label="KANBAN.SETTINGS.CONTACT_FIELDS.MOVE_UP"]'
        )
        .trigger('click');
      expect(wrapper.emitted('update:modelValue')).toEqual([
        [['waha_whatsapp_jid', 'date_of_birth', 'cpf']],
      ]);
    } finally {
      wrapper.unmount();
    }
  });
});
