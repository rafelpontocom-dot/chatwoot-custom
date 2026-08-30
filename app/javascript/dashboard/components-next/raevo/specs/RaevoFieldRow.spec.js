import { mount } from '@vue/test-utils';
import RaevoFieldRow from '../RaevoFieldRow.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) => {
      if (key === 'RAEVO.FIELD_ROW.EDIT') return `Editar ${values.field}`;
      if (key === 'RAEVO.FIELD_ROW.EMPTY') return '—';
      return key;
    },
  }),
}));

const CONTROLE = `
  <template #control="{ controlClass, fieldId }">
    <input :id="fieldId" :class="controlClass" />
  </template>
`;

const montar = (props = {}) =>
  mount(RaevoFieldRow, {
    props: { label: 'Valor', ...props },
    slots: { control: CONTROLE },
    attachTo: document.body,
  });

describe('RaevoFieldRow', () => {
  it('reads as a single row, with label and value side by side', () => {
    const wrapper = montar({ value: '480,00' });
    const linha = wrapper.find('[data-testid="raevo-field-row-read"]');

    expect(linha.text()).toContain('Valor');
    expect(linha.text()).toContain('480,00');
    // A densidade é o ponto: a linha não pode voltar a custar 62px.
    expect(linha.classes()).toContain('min-h-8');
    expect(wrapper.find('input').exists()).toBe(false);
  });

  it('shows a dash for an empty value instead of blank space', () => {
    const wrapper = montar({ value: '' });

    expect(
      wrapper.find('[data-testid="raevo-field-row-read"]').text()
    ).toContain('—');
  });

  it('treats whitespace as empty', () => {
    const wrapper = montar({ value: '   ' });

    expect(
      wrapper.find('[data-testid="raevo-field-row-read"]').text()
    ).toContain('—');
  });

  it('becomes a full field when the row is clicked', async () => {
    const wrapper = montar({ value: '480,00' });

    await wrapper.find('[data-testid="raevo-field-row-read"]').trigger('click');

    // Em edição volta o rótulo em cima: é onde o preenchimento é 2x mais rápido.
    expect(wrapper.find('label').exists()).toBe(true);
    expect(wrapper.find('input').exists()).toBe(true);
    expect(wrapper.find('[data-testid="raevo-field-row-read"]').exists()).toBe(
      false
    );
    expect(wrapper.emitted('open')).toBeTruthy();
  });

  it('moves focus into the control so the keyboard never stalls', async () => {
    const wrapper = montar();

    await wrapper.find('[data-testid="raevo-field-row-read"]').trigger('click');
    await wrapper.vm.$nextTick();

    expect(document.activeElement).toBe(wrapper.find('input').element);
    wrapper.unmount();
  });

  it('leaves edit mode on Escape without swallowing it from the panel', async () => {
    const wrapper = montar();
    await wrapper.find('[data-testid="raevo-field-row-read"]').trigger('click');

    await wrapper.find('input').trigger('keydown', { key: 'Escape' });

    expect(wrapper.find('[data-testid="raevo-field-row-read"]').exists()).toBe(
      true
    );
    expect(wrapper.emitted('close')).toBeTruthy();
  });

  it('commits on Enter for single-line controls but not for a textarea', async () => {
    const linha = montar();
    await linha.find('[data-testid="raevo-field-row-read"]').trigger('click');
    await linha.find('input').trigger('keydown', { key: 'Enter' });
    expect(linha.find('[data-testid="raevo-field-row-read"]').exists()).toBe(
      true
    );

    const longo = montar({ variant: 'textarea' });
    await longo.find('[data-testid="raevo-field-row-read"]').trigger('click');
    await longo.find('input').trigger('keydown', { key: 'Enter' });
    // Enter num texto longo é quebra de linha, não confirmação.
    expect(longo.find('[data-testid="raevo-field-row-read"]').exists()).toBe(
      false
    );
  });

  it('does not open when disabled', async () => {
    const wrapper = montar({ disabled: true });

    await wrapper.find('[data-testid="raevo-field-row-read"]').trigger('click');

    expect(wrapper.find('input').exists()).toBe(false);
    expect(wrapper.emitted('open')).toBeFalsy();
  });

  it('keeps the row reachable by keyboard as a real button', () => {
    const linha = montar().find('[data-testid="raevo-field-row-read"]');

    expect(linha.element.tagName).toBe('BUTTON');
    expect(linha.attributes('aria-label')).toBe('Editar Valor');
  });
});
