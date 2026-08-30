import {
  nextKanbanStageColor,
  AUTO_STAGE_COLOR_SEQUENCE,
  getKanbanStageColorOption,
} from '../kanbanStageColors';

describe('Raevo · cores automáticas de etapa', () => {
  it('percorre a sequência validada pela posição', () => {
    expect(nextKanbanStageColor(0)).toBe('blue');
    expect(nextKanbanStageColor(1)).toBe('teal');
    expect(nextKanbanStageColor(2)).toBe('amber');
    expect(nextKanbanStageColor(3)).toBe('violet');
  });

  it('recomeça a sequência depois da quarta etapa', () => {
    expect(nextKanbanStageColor(4)).toBe('blue');
    expect(nextKanbanStageColor(9)).toBe('teal');
  });

  it('não quebra com posição inválida', () => {
    expect(AUTO_STAGE_COLOR_SEQUENCE).toContain(
      nextKanbanStageColor(undefined)
    );
    expect(AUTO_STAGE_COLOR_SEQUENCE).toContain(nextKanbanStageColor(null));
    expect(AUTO_STAGE_COLOR_SEQUENCE).toContain(nextKanbanStageColor(-3));
  });

  it('cada cor da sequência tem barra, ponto e tinta próprias', () => {
    AUTO_STAGE_COLOR_SEQUENCE.forEach(cor => {
      const o = getKanbanStageColorOption(cor);
      expect(o.barClass).toBeTruthy();
      expect(o.dotClass).toBeTruthy();
      expect(o.inkClass).toBeTruthy();
    });
  });
});
