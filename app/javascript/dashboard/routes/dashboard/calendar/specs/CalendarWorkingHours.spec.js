import { mount } from '@vue/test-utils';

import CalendarWorkingHours from '../CalendarWorkingHours.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const regra = (extra = {}) => ({
  id: 1,
  kind: 'weekly_window',
  active: true,
  weekday: 1,
  starts_at_local: '09:00',
  ends_at_local: '18:00',
  ...extra,
});

const monta = (rules = []) => mount(CalendarWorkingHours, { props: { rules } });

describe('CalendarWorkingHours', () => {
  it('mostra os sete dias, começando à segunda', () => {
    const wrapper = monta();

    const dias = wrapper.findAll('[data-testid^="working-day-toggle-"]');
    expect(dias).toHaveLength(7);
    expect(dias[0].attributes('data-testid')).toBe('working-day-toggle-1');
    expect(dias[6].attributes('data-testid')).toBe('working-day-toggle-0');
  });

  it('diz que o dia está fechado em vez de o deixar em branco', () => {
    const wrapper = monta();

    expect(wrapper.find('[data-testid="working-day-closed-1"]').exists()).toBe(
      true
    );
  });

  it('cria o horário comum ao ligar um dia', async () => {
    const wrapper = monta();

    await wrapper
      .find('[data-testid="working-day-toggle-2"]')
      .trigger('change');

    expect(wrapper.emitted('create')).toEqual([
      [{ weekday: 2, startsAtLocal: '09:00', endsAtLocal: '18:00' }],
    ]);
  });

  it('apaga todos os intervalos ao desligar um dia', async () => {
    const wrapper = monta([
      regra(),
      regra({ id: 2, starts_at_local: '19:00', ends_at_local: '20:00' }),
    ]);

    await wrapper
      .find('[data-testid="working-day-toggle-1"]')
      .trigger('change');

    expect(wrapper.emitted('remove')).toHaveLength(2);
    expect(wrapper.emitted('create')).toBeUndefined();
  });

  it('acrescenta um segundo período que começa onde o primeiro acabou', async () => {
    const wrapper = monta([regra()]);

    await wrapper.find('[data-testid="working-day-add-1"]').trigger('click');

    // Nunca de duração zero: o servidor recusa fim igual ao início.
    expect(wrapper.emitted('create')).toEqual([
      [{ weekday: 1, startsAtLocal: '18:00', endsAtLocal: '19:00' }],
    ]);
  });

  it('não passa das 23:59 ao acrescentar um período tardio', async () => {
    const wrapper = monta([regra({ ends_at_local: '23:00' })]);

    await wrapper.find('[data-testid="working-day-add-1"]').trigger('click');

    expect(wrapper.emitted('create')[0][0].endsAtLocal).toBe('23:59');
  });

  it('edita a hora no sítio, sem apagar e voltar a criar', async () => {
    const wrapper = monta([regra()]);

    // `setValue` já dispara `change` num campo de hora; disparar outra vez
    // duplicava o pedido de gravação.
    const campo = wrapper.findAll('input[type="time"]')[1];
    await campo.setValue('17:00');

    expect(wrapper.emitted('update')).toEqual([
      [
        {
          rule: expect.objectContaining({ id: 1 }),
          changes: { ends_at_local: '17:00' },
        },
      ],
    ]);
  });

  it('ignora as regras que não são janelas semanais', () => {
    const wrapper = monta([
      regra({ id: 7, kind: 'block', date: '2026-09-01' }),
    ]);

    expect(wrapper.find('[data-testid="working-day-closed-1"]').exists()).toBe(
      true
    );
  });

  it('ordena os intervalos do dia pela hora de início', () => {
    const wrapper = monta([
      regra({ id: 2, starts_at_local: '14:00', ends_at_local: '18:00' }),
      regra({ id: 1, starts_at_local: '08:00', ends_at_local: '12:00' }),
    ]);

    const horas = wrapper
      .findAll('input[type="time"]')
      .map(campo => campo.element.value);
    expect(horas).toEqual(['08:00', '12:00', '14:00', '18:00']);
  });
});
