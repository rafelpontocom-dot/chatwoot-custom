import { mount } from '@vue/test-utils';
import RaevoHomeGrid from '../RaevoHomeGrid.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values) => (values ? `${key} ${JSON.stringify(values)}` : key),
  }),
}));

const items = [
  { id: 'kpi-conversations', x: 0, y: 0, w: 3, h: 2 },
  { id: 'kpi-actions', x: 3, y: 0, w: 3, h: 2 },
];
const labels = { 'kpi-conversations': 'Conversas', 'kpi-actions': 'Ações' };

const mountGrid = (props = {}) =>
  mount(RaevoHomeGrid, {
    props: { items, labels, editing: true, ...props },
    slots: { widget: '<div class="content">{{ params.item.id }}</div>' },
    global: {
      stubs: {
        RaevoField: {
          template:
            '<div><slot control-class="campo" field-id="campo-id" /></div>',
        },
      },
    },
    attachTo: document.body,
  });

const lastUpdate = wrapper => wrapper.emitted('update:items').at(-1)[0];

describe('RaevoHomeGrid', () => {
  it('shows no handles, corners or plus outside edit mode', () => {
    const wrapper = mountGrid({ editing: false });

    expect(wrapper.find('[data-testid="home-widget-adjust"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-testid="home-add-widget"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-widget-id]').attributes('tabindex')).toBe(
      undefined
    );
    wrapper.unmount();
  });

  // WCAG 2.2, 2.5.7: arrastar nunca é o único caminho.
  it('moves with arrow keys and resizes with Shift and arrows', async () => {
    const wrapper = mountGrid();
    const widget = wrapper.get('[data-widget-id="kpi-actions"]');

    await widget.trigger('keydown', { key: 'ArrowDown' });
    expect(lastUpdate(wrapper).find(i => i.id === 'kpi-actions')).toMatchObject(
      { x: 3, y: 1 }
    );

    await widget.trigger('keydown', { key: 'ArrowRight', shiftKey: true });
    expect(lastUpdate(wrapper).find(i => i.id === 'kpi-actions')).toMatchObject(
      { w: 4, h: 2 }
    );
    wrapper.unmount();
  });

  it('announces where the block landed', async () => {
    const wrapper = mountGrid();
    await wrapper
      .get('[data-widget-id="kpi-actions"]')
      .trigger('keydown', { key: 'ArrowRight' });

    expect(wrapper.get('[aria-live="polite"]').text()).toContain(
      '"name":"Ações","column":5,"row":1'
    );
    wrapper.unmount();
  });

  it('offers move and size buttons for a single pointer', async () => {
    const wrapper = mountGrid();
    const widget = wrapper.get('[data-widget-id="kpi-conversations"]');

    await widget.get('[data-testid="home-widget-adjust"]').trigger('click');
    await widget
      .get('[data-testid="home-widget-size-taller"]')
      .trigger('click');
    expect(lastUpdate(wrapper).find(i => i.id === 'kpi-conversations').h).toBe(
      3
    );

    await widget.get('[data-testid="home-widget-title"]').setValue('Fila');
    await widget.get('[data-testid="home-widget-title"]').trigger('change');
    expect(wrapper.emitted('rename').at(-1)).toEqual([
      'kpi-conversations',
      'Fila',
    ]);
    wrapper.unmount();
  });

  it('a click on a block is not a drag', async () => {
    const wrapper = mountGrid();
    const widget = wrapper.get('[data-widget-id="kpi-actions"]');

    // O jsdom não tem PointerEvent; o MouseEvent leva as mesmas coordenadas.
    const Pointer = window.PointerEvent || MouseEvent;
    widget.element.dispatchEvent(
      new Pointer('pointerdown', { clientX: 10, clientY: 10, bubbles: true })
    );
    window.dispatchEvent(
      new Pointer('pointermove', { clientX: 12, clientY: 11 })
    );
    window.dispatchEvent(new Pointer('pointerup'));

    expect(wrapper.emitted('update:items')).toBeUndefined();
    wrapper.unmount();
  });

  it('keeps the content out of reach while editing', () => {
    const wrapper = mountGrid();
    expect(
      wrapper.get('.content').element.parentElement.hasAttribute('inert')
    ).toBe(true);
    wrapper.unmount();
  });
});
