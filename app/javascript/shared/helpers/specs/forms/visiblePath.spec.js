import { visiblePathKeys } from 'shared/helpers/forms/visiblePath';
import { matches, satisfied } from 'shared/helpers/forms/logic';

const schema = (fields, logics = []) => ({
  sections: [{ key: 's', fields }],
  logics,
});

const field = (key, extra = {}) => ({
  key,
  type: 'text',
  label: key,
  ...extra,
});

describe('visiblePathKeys', () => {
  it('walks every question when no rule interferes', () => {
    const path = visiblePathKeys(
      schema([field('a'), field('b'), field('c')]),
      {}
    );

    expect(path).toEqual(['a', 'b', 'c']);
  });

  it('skips what a jump leaves behind, not only what a condition names', () => {
    // É a diferença entre esconder e saltar: `b` não é mencionada por nenhuma
    // condição e mesmo assim não foi vista.
    const path = visiblePathKeys(
      schema(
        [field('a'), field('b'), field('c')],
        [
          {
            field_key: 'a',
            payloads: [
              {
                condition: { ref: 'a', comparison: 'is', expected: 'saltar' },
                action: { kind: 'navigate', field_key: 'c' },
              },
            ],
          },
        ]
      ),
      { a: 'saltar' }
    );

    expect(path).toEqual(['a', 'c']);
  });

  it('follows the first rule that holds and ignores the rest', () => {
    const logics = [
      {
        field_key: 'a',
        payloads: [
          {
            condition: { ref: 'a', comparison: 'is', expected: 'x' },
            action: { kind: 'navigate', field_key: 'b' },
          },
          {
            condition: { ref: 'a', comparison: 'is_not_empty' },
            action: { kind: 'navigate', field_key: 'c' },
          },
        ],
      },
    ];
    const path = visiblePathKeys(
      schema([field('a'), field('b'), field('c')], logics),
      { a: 'x' }
    );

    expect(path).toEqual(['a', 'b', 'c']);
  });

  it('ends the walk when a rule jumps to an ending', () => {
    const path = visiblePathKeys(
      schema(
        [field('a'), field('b')],
        [
          {
            field_key: 'a',
            payloads: [
              {
                condition: { ref: 'a', comparison: 'is_not_empty' },
                action: { kind: 'navigate', field_key: 'obrigado' },
              },
            ],
          },
        ]
      ),
      { a: 'sim' }
    );

    expect(path).toEqual(['a']);
  });

  it('never walks backwards, so two rules pointing at each other still end', () => {
    const logics = [
      {
        field_key: 'b',
        payloads: [
          {
            condition: { ref: 'b', comparison: 'is_not_empty' },
            action: { kind: 'navigate', field_key: 'a' },
          },
        ],
      },
    ];
    const path = visiblePathKeys(schema([field('a'), field('b')], logics), {
      b: 'volta',
    });

    expect(path).toEqual(['a', 'b']);
  });

  it('still honours a condition from an already published version', () => {
    // Versões publicadas são imutáveis e trazem `visible_when` com `equals`.
    const fields = [
      field('a'),
      field('b', {
        visible_when: { field: 'a', operator: 'equals', value: 'sim' },
      }),
    ];

    expect(visiblePathKeys(schema(fields), { a: 'nao' })).toEqual(['a']);
    expect(visiblePathKeys(schema(fields), { a: 'sim' })).toEqual(['a', 'b']);
  });
});

describe('logic comparators', () => {
  it('compares numbers as numbers, and refuses what is not one', () => {
    expect(matches('greater_than', '12', '5')).toBe(true);
    expect(matches('greater_than', '12abc', '5')).toBe(false);
    expect(matches('less_or_equal_than', '3,5', '4')).toBe(true);
  });

  it('treats a multiple selection as a set for `is` and a member for `contains`', () => {
    expect(matches('is', ['b', 'a'], ['a', 'b'])).toBe(true);
    expect(matches('is', ['a'], ['a', 'b'])).toBe(false);
    expect(matches('contains', ['a', 'b'], 'b')).toBe(true);
  });

  it('reads an unchecked consent as empty', () => {
    expect(matches('is_empty', false)).toBe(true);
    expect(matches('is_not_empty', true)).toBe(true);
  });

  it('combines conditions with and/or, one level deep', () => {
    const group = {
      combinator: 'any',
      conditions: [
        { ref: 'x', comparison: 'is', expected: '1' },
        { ref: 'y', comparison: 'is', expected: '2' },
      ],
    };

    expect(satisfied(group, { y: '2' })).toBe(true);
    expect(satisfied({ ...group, combinator: 'all' }, { y: '2' })).toBe(false);
  });

  it('never fires an empty group', () => {
    expect(satisfied({ combinator: 'all', conditions: [] }, {})).toBe(false);
  });

  it('returns false for an operator it does not know, instead of throwing', () => {
    expect(matches('inventado', 'a', 'a')).toBe(false);
  });
});
