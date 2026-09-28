import { mount } from '@vue/test-utils';
import { computed, ref } from 'vue';
import SetupTab from '../procedure/SetupTab.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const copiar = vi.fn();
vi.mock('shared/helpers/clipboard', () => ({
  copyTextToClipboard: (...args) => copiar(...args),
}));

const draft = ref({});
const bookingPageUrl = ref('');
vi.mock('../procedure/procedureDraft', () => ({
  useProcedureDraft: () => ({
    draft,
    errors: computed(() => ({})),
    bookingPageUrl,
  }),
}));

const stubs = {
  SetupGroup: { template: '<div><slot /></div>' },
  SetupRow: { template: '<div><slot /></div>' },
  SetupSwitch: { props: ['modelValue', 'label'], template: '<div />' },
  RaevoField: {
    props: ['label', 'error', 'compact', 'variant'],
    template:
      '<label>{{ label }}<slot :field-id="\'f\'" :control-class="\'c\'" /></label>',
  },
};

const montar = ({
  publicado = true,
  slug = 'consulta',
  url = 'https://crm.raevo.io/agendar/tok',
} = {}) => {
  draft.value = {
    name: 'Consulta',
    public_slug: slug,
    public_booking_enabled: publicado,
    duration_minutes: 30,
    location_type: 'in_person',
    color: 'BLUE',
    max_sessions: 1,
    recurrence_allowed: false,
  };
  bookingPageUrl.value = url;
  return mount(SetupTab, { global: { stubs } });
};

describe('SetupTab · endereço público', () => {
  beforeEach(() => vi.clearAllMocks());

  it('opens the patient page at the address the procedure will really have', () => {
    const wrapper = montar();

    expect(
      wrapper
        .find('[data-testid="calendar-procedure-open-link"]')
        .attributes('href')
    ).toBe('https://crm.raevo.io/agendar/tok/consulta');
  });

  it('copies the same address', async () => {
    const wrapper = montar();

    await wrapper
      .find('[data-testid="calendar-procedure-copy-link"]')
      .trigger('click');

    expect(copiar).toHaveBeenCalledWith(
      'https://crm.raevo.io/agendar/tok/consulta'
    );
  });

  // Antes de publicar o endereço não existe: abrir levaria o utilizador a 404.
  it('offers nothing to open while the procedure is not published', () => {
    const wrapper = montar({ publicado: false });

    expect(
      wrapper.find('[data-testid="calendar-procedure-open-link"]').exists()
    ).toBe(false);
  });

  it('offers nothing to open when the account has no booking page yet', () => {
    const wrapper = montar({ url: '' });

    expect(
      wrapper.find('[data-testid="calendar-procedure-copy-link"]').exists()
    ).toBe(false);
  });
});
