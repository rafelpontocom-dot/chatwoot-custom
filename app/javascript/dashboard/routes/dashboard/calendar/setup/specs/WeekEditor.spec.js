import { mount } from '@vue/test-utils';
import WeekEditor from '../shared/WeekEditor.vue';
import TimeField from '../shared/TimeField.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const monta = weekly => mount(WeekEditor, { props: { modelValue: weekly } });
const ultimo = wrapper => wrapper.emitted('update:modelValue').at(-1)[0];

describe('WeekEditor', () => {
  it('abre um dia fechado com um intervalo e fecha-o de novo', async () => {
    const wrapper = monta([]);

    await wrapper
      .find('[data-testid="calendar-week-day-2"] [role="switch"]')
      .trigger('click');
    expect(ultimo(wrapper)).toEqual([
      { weekday: 2, ranges: [{ from: '08:00', to: '12:00' }] },
    ]);

    await wrapper.setProps({ modelValue: ultimo(wrapper) });
    await wrapper
      .find('[data-testid="calendar-week-day-2"] [role="switch"]')
      .trigger('click');
    expect(ultimo(wrapper)).toEqual([]);
  });

  it('acrescenta um segundo intervalo a partir do fim do primeiro', async () => {
    const wrapper = monta([
      { weekday: 3, ranges: [{ from: '08:00', to: '12:00' }] },
    ]);

    const dia = wrapper.find('[data-testid="calendar-week-day-3"]');
    await dia
      .findAll('button')
      .find(button => button.text() === 'CALENDAR_SETUP.SCHEDULES.ADD_RANGE')
      .trigger('click');

    expect(ultimo(wrapper)[0].ranges).toEqual([
      { from: '08:00', to: '12:00' },
      { from: '12:00', to: '12:00' },
    ]);
  });

  it('copia os intervalos de um dia para os dias escolhidos, por botão', async () => {
    const wrapper = monta([
      { weekday: 1, ranges: [{ from: '09:00', to: '13:00' }] },
    ]);

    const segunda = wrapper.find('[data-testid="calendar-week-day-1"]');
    await segunda
      .findAll('button')
      .find(button => button.text() === 'CALENDAR_SETUP.SCHEDULES.COPY_TO')
      .trigger('click');
    const painel = wrapper.find('[data-testid="calendar-week-copy-1"]');
    const caixas = painel.findAll('input[type="checkbox"]');
    await caixas[1].setValue(true);
    await caixas[3].setValue(true);
    await painel.findAll('button').at(-1).trigger('click');

    expect(ultimo(wrapper).map(day => day.weekday)).toEqual([1, 3, 5]);
    expect(ultimo(wrapper)[2].ranges).toEqual([{ from: '09:00', to: '13:00' }]);
  });
});

describe('TimeField', () => {
  it.each([
    ['8', '08:00'],
    ['830', '08:30'],
    ['18:5', '18:05'],
    ['1400', '14:00'],
  ])('entende %s como %s', async (digitado, esperado) => {
    const wrapper = mount(TimeField, {
      props: { modelValue: '10:00', label: 'Início' },
    });

    await wrapper.find('input').setValue(digitado);
    await wrapper.find('input').trigger('blur');

    expect(wrapper.emitted('update:modelValue')[0]).toEqual([esperado]);
  });

  it('recusa hora impossível e volta ao valor anterior', async () => {
    const wrapper = mount(TimeField, {
      props: { modelValue: '10:00', label: 'Início' },
    });

    await wrapper.find('input').setValue('2599');
    await wrapper.find('input').trigger('blur');

    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
    expect(wrapper.find('input').element.value).toBe('10:00');
  });
});
