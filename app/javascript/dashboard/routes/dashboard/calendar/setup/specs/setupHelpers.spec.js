import { toSlug, weekSummary } from '../setupHelpers';
import { draftFrom, procedurePayload } from '../procedure/procedureDraft';

const DIAS = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
const faixa = (from, to) => ({ from, to });

describe('weekSummary', () => {
  it('resume dias seguidos com o mesmo horário como no mockup', () => {
    const semana = [1, 2, 3, 4, 5].map(weekday => ({
      weekday,
      ranges: [faixa('08:00', '18:00')],
    }));

    expect(weekSummary(semana, DIAS)).toBe('Seg–sex, 08:00–18:00');
  });

  it('separa dias soltos e dias com outro horário', () => {
    const semana = [
      { weekday: 1, ranges: [faixa('08:00', '12:00')] },
      {
        weekday: 3,
        ranges: [faixa('08:00', '12:00'), faixa('14:00', '16:00')],
      },
      { weekday: 5, ranges: [faixa('08:00', '12:00')] },
    ];

    expect(weekSummary(semana, DIAS)).toBe(
      'Seg, sex · 08:00–12:00; qua · 08:00–12:00 e 14:00–16:00'
    );
  });
});

describe('procedureDraft', () => {
  it('lê o horário só do procedimento e grava de volta como horário nomeado', () => {
    const rascunho = draftFrom({
      id: 4,
      name: 'Avaliação com laser CO2',
      duration_minutes: 50,
      availability_mode: 'schedule',
      own_schedule: true,
      schedule_id: 9,
      assignment_strategy: 'patient_choice',
      team_id: 3,
      payment_mode: 'full',
      deposit_cents: 5000,
    });

    expect(rascunho.when_mode).toBe('own');
    const payload = procedurePayload(rascunho);
    expect(payload.availability_mode).toBe('schedule');
    // Sem estratégia de equipe, a equipe não vai; sem sinal, o valor do sinal também não.
    expect(payload.team_id).toBeNull();
    expect(payload.deposit_cents).toBeNull();
    expect(payload.public_booking_config.questions[0].key).toBe('full_name');
  });

  it('gera o link público a partir do nome', () => {
    expect(toSlug('Avaliação com Laser CO2')).toBe('avaliacao-com-laser-co2');
  });
});
