import { nextTick, ref } from 'vue';
import { useAppointmentResources } from '../useAppointmentResources';

const anaProfissional = { id: 1, name: 'Dra. Ana', resource_type: 'user' };
const brunoProfissional = { id: 2, name: 'Dr. Bruno', resource_type: 'user' };
const sala = { id: 3, name: 'Sala 1', resource_type: 'room' };
const laser = { id: 4, name: 'Laser CO2', resource_type: 'equipment' };
const arquivada = {
  id: 5,
  name: 'Sala antiga',
  resource_type: 'room',
  active: false,
};
const todos = [anaProfissional, brunoProfissional, sala, laser, arquivada];

const montar = ({ procedimento, preferidos = [] }) =>
  useAppointmentResources({
    procedure: ref(procedimento),
    resources: ref(todos),
    preferredResourceIds: ref(preferidos),
  });

describe('useAppointmentResources', () => {
  describe('quando o procedimento lista os recursos que aceita', () => {
    const toxina = { id: 9, resource_ids: [1, 2, 3] };

    it('mostra só os tipos que ele aceita, todos obrigatórios', () => {
      const { fields } = montar({ procedimento: toxina });

      expect(
        fields.value.map(field => [
          field.key,
          field.options.map(option => option.id),
          field.required,
        ])
      ).toEqual([
        ['professional', [1, 2], true],
        ['room', [3], true],
      ]);
    });

    it('já preenche o tipo que só tem uma opção', () => {
      const { selection } = montar({ procedimento: toxina });

      expect(selection.value.room).toBe('3');
      expect(selection.value.professional).toBe('');
    });

    it('não está completo enquanto falta a profissional', () => {
      const { isComplete, missingKinds, selection } = montar({
        procedimento: toxina,
      });

      expect(missingKinds.value).toEqual(['professional']);
      expect(isComplete.value).toBe(false);

      selection.value.professional = '2';
      expect(isComplete.value).toBe(true);
    });
  });

  describe('quando o procedimento aceita qualquer recurso', () => {
    const consulta = { id: 8, resource_ids: [] };

    it('mostra os tipos que existem, sem obrigar e sem pré-escolher', () => {
      // Obrigar e pré-preencher aqui marcava o único laser em cada consulta.
      const { fields, selection } = montar({ procedimento: consulta });

      expect(fields.value.map(field => [field.key, field.required])).toEqual([
        ['professional', false],
        ['room', false],
        ['equipment', false],
      ]);
      expect(selection.value.equipment).toBe('');
    });

    it('exige pelo menos um recurso', () => {
      const { isComplete, selection } = montar({ procedimento: consulta });

      expect(isComplete.value).toBe(false);
      selection.value.room = '3';
      expect(isComplete.value).toBe(true);
    });
  });

  it('nunca oferece um recurso arquivado', () => {
    const { fields } = montar({ procedimento: { id: 8, resource_ids: [] } });
    const salas = fields.value.find(field => field.key === 'room');

    expect(salas.options.map(option => option.id)).toEqual([3]);
  });

  it('preenche a profissional cuja agenda é a única à vista', () => {
    // Pedido do Alysson: estando na agenda de uma profissional, ela já vem.
    const { selection } = montar({
      procedimento: { id: 9, resource_ids: [1, 2, 3] },
      preferidos: [2],
    });

    expect(selection.value.professional).toBe('2');
  });

  it('envia todos os recursos escolhidos, um por tipo', () => {
    const { resourceIds, selection } = montar({
      procedimento: { id: 9, resource_ids: [1, 2, 3] },
    });
    selection.value.professional = '1';

    expect(resourceIds.value).toEqual([1, 3]);
  });

  it('ao remarcar, recupera todos os recursos da consulta e não só o primeiro', () => {
    // Remarcar gravava só `resources[0]`: uma consulta com profissional e sala
    // perdia a sala em silêncio.
    const { resourceIds, selectResourceIds } = montar({
      procedimento: { id: 8, resource_ids: [] },
    });

    selectResourceIds([2, 3, 4]);

    expect(resourceIds.value).toEqual([2, 3, 4]);
  });

  it('larga a escolha que o novo procedimento já não aceita', async () => {
    const procedimento = ref({ id: 8, resource_ids: [] });
    const { selection } = useAppointmentResources({
      procedure: procedimento,
      resources: ref(todos),
    });
    selection.value.equipment = '4';

    procedimento.value = { id: 9, resource_ids: [1, 2, 3] };
    await nextTick();

    expect(selection.value.equipment).toBe('');
    expect(selection.value.room).toBe('3');
  });
});
