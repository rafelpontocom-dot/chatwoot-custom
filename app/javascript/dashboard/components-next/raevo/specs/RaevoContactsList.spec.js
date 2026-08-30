import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import RaevoContactsList from '../RaevoContactsList.vue';

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: {
    en: {
      CONTACTS_LAYOUT: {
        CARD: { SELECT: 'Select contact' },
        TABLE: {
          NAME: 'Name',
          EMAIL: 'Email',
          PHONE: 'Phone',
          COMPANY: 'Company',
          LABELS: 'Labels',
          LAST_ACTIVITY: 'Last activity',
        },
      },
    },
  },
});

const push = vi.fn();
const mountList = contacts =>
  mount(RaevoContactsList, {
    props: { contacts, selectedContactIds: [] },
    global: {
      plugins: [i18n],
      stubs: { Avatar: true },
      mocks: {
        $route: { params: { accountId: '1' } },
      },
      provide: {},
    },
  });

vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
  useRoute: () => ({ params: { accountId: '1' } }),
}));

describe('RaevoContactsList', () => {
  // Raevo · Sereno — o store camelCasa o contato, a API responde snake_case.
  // A tabela precisa ler as duas formas. Ver docs/raevo-design-system.md.
  it('reads camelCase fields coming from the store', () => {
    const w = mountList([
      {
        id: 1,
        name: 'Marina Alves',
        email: 'marina@ex.com',
        phoneNumber: '+55 62 99812-4477',
        lastActivityAt: Math.floor(Date.now() / 1000) - 600,
        labels: ['Lead'],
      },
    ]);
    const linha = w.find('[data-testid="raevo-contact-row-1"]').text();
    expect(linha).toContain('Marina Alves');
    expect(linha).toContain('+55 62 99812-4477');
  });

  it('reads snake_case fields coming straight from the API', () => {
    const w = mountList([
      {
        id: 2,
        name: 'Bruno Tavares',
        email: 'bruno@ex.com',
        phone_number: '+55 62 99671-5544',
        last_activity_at: Math.floor(Date.now() / 1000) - 600,
      },
    ]);
    expect(w.find('[data-testid="raevo-contact-row-2"]').text()).toContain(
      '+55 62 99671-5544'
    );
  });

  it('renders one row per contact with the Sereno table shell', () => {
    const w = mountList([
      { id: 1, name: 'A' },
      { id: 2, name: 'B' },
      { id: 3, name: 'C' },
    ]);
    expect(w.find('[data-testid="raevo-contacts-table"]').exists()).toBe(true);
    expect(w.findAll('tbody tr')).toHaveLength(3);
  });

  it('emits the contact id when the checkbox is toggled', async () => {
    const w = mountList([{ id: 7, name: 'Marina' }]);
    await w.find('input[type="checkbox"]').setValue(true);
    expect(w.emitted('toggleContact')[0]).toEqual([7]);
  });
});
