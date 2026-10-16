import {
  DEFAULT_OPPORTUNITY_SECTION_ORDER,
  moveOpportunitySection,
  resolveOpportunitySectionOrder,
} from '../kanbanOpportunitySections';

describe('kanbanOpportunitySections', () => {
  describe('resolveOpportunitySectionOrder', () => {
    it('falls back to the default order when nothing was saved', () => {
      expect(resolveOpportunitySectionOrder(undefined)).toEqual([
        ...DEFAULT_OPPORTUNITY_SECTION_ORDER,
      ]);
      expect(resolveOpportunitySectionOrder(null)).toEqual([
        ...DEFAULT_OPPORTUNITY_SECTION_ORDER,
      ]);
      expect(resolveOpportunitySectionOrder('finance')).toEqual([
        ...DEFAULT_OPPORTUNITY_SECTION_ORDER,
      ]);
    });

    it('keeps the saved order', () => {
      expect(
        resolveOpportunitySectionOrder([
          'timeline',
          'finance',
          'contact-details',
          'calendar',
          'forms',
        ])
      ).toEqual([
        'timeline',
        'finance',
        'contact-details',
        'calendar',
        'forms',
      ]);
    });

    it('appends sections the product gained after the preference was saved', () => {
      expect(
        resolveOpportunitySectionOrder(['timeline', 'contact-details'])
      ).toEqual([
        'timeline',
        'contact-details',
        'calendar',
        'finance',
        'forms',
      ]);
    });

    // Uma chave que o produto não conhece desenharia uma secção vazia.
    it('drops keys this version no longer has, and repeated keys', () => {
      expect(
        resolveOpportunitySectionOrder([
          'finance',
          'tarefas',
          'finance',
          { name: 'timeline' },
        ])
      ).toEqual([
        'finance',
        'timeline',
        'contact-details',
        'calendar',
        'forms',
      ]);
    });
  });

  describe('moveOpportunitySection', () => {
    const ordem = [...DEFAULT_OPPORTUNITY_SECTION_ORDER];

    it('moves a section up and down', () => {
      expect(moveOpportunitySection(ordem, 'finance', -1)).toEqual([
        'contact-details',
        'finance',
        'calendar',
        'forms',
        'timeline',
      ]);
      expect(moveOpportunitySection(ordem, 'finance', 1)).toEqual([
        'contact-details',
        'calendar',
        'forms',
        'finance',
        'timeline',
      ]);
    });

    it('does nothing at either edge, or for a section it does not hold', () => {
      expect(moveOpportunitySection(ordem, 'contact-details', -1)).toEqual(
        ordem
      );
      expect(moveOpportunitySection(ordem, 'timeline', 1)).toEqual(ordem);
      expect(moveOpportunitySection(ordem, 'tarefas', -1)).toEqual(ordem);
    });

    // Com o Financeiro desligado, subir «Formulários» tem de passar à frente de
    // «Agenda» — não trocar com uma secção que ninguém vê.
    it('swaps with the visible neighbour, skipping hidden sections', () => {
      const visiveis = ['contact-details', 'calendar', 'forms', 'timeline'];

      expect(moveOpportunitySection(ordem, 'forms', -1, visiveis)).toEqual([
        'contact-details',
        'forms',
        'finance',
        'calendar',
        'timeline',
      ]);
    });
  });
});
