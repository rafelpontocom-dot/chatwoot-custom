import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { withFullI18n } from 'test-i18n';
import ContactsForm from '../ContactsForm.vue';

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    currentAccount: ref({ id: 1 }),
    isCloudFeatureEnabled: () => false,
  }),
}));

const i18n = withFullI18n('pt_BR');

describe('ContactsForm social profiles', () => {
  it.each(['pt_BR', 'pt'])(
    'renders every social profile with a translated placeholder in %s',
    async locale => {
      i18n.global.locale.value = locale;
      const wrapper = mount(ContactsForm, {
        props: {
          contactData: {
            id: 1,
            name: 'Pedro Raevo',
            additionalAttributes: { socialProfiles: { whatsapp: '@pedro' } },
          },
        },
        global: {
          stubs: {
            PhoneNumberInput: true,
            ComboBox: true,
            CompanySelector: true,
          },
        },
      });

      const profiles = wrapper.findAll('input[size]');
      expect(profiles).toHaveLength(8);
      profiles.forEach(input => {
        expect(input.attributes('placeholder')).toBeTruthy();
        expect(input.attributes('placeholder')).not.toContain(
          'CONTACTS_LAYOUT.'
        );
        expect(Number(input.attributes('size'))).toBeGreaterThan(0);
      });

      const whatsapp = profiles.find(input => input.element.value === 'pedro');
      expect(whatsapp).toBeDefined();
      await whatsapp.setValue('@@novo');
      expect(
        wrapper.emitted('update').at(-1)[0].additionalAttributes.socialProfiles
          .whatsapp
      ).toBe('novo');
      wrapper.unmount();
    }
  );
});
