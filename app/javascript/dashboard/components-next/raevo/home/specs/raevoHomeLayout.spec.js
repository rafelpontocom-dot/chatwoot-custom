import {
  DEFAULT_HOME_LAYOUT,
  addItem,
  compactLayout,
  layoutToSave,
  moveItem,
  removeItem,
  renameItem,
  resizeItem,
  resolveLayout,
  sanitizeLayout,
  visibleLayout,
} from '../raevoHomeLayout';

const overlaps = items =>
  items.some((a, i) =>
    items
      .slice(i + 1)
      .some(
        b =>
          a.x < b.x + b.w &&
          b.x < a.x + a.w &&
          a.y < b.y + b.h &&
          b.y < a.y + a.h
      )
  );

const byId = (items, id) => items.find(item => item.id === id);
const layout = items => ({ version: 1, items });

describe('raevoHomeLayout', () => {
  it('the default layout is the Home people already know, with no overlap', () => {
    expect(overlaps(DEFAULT_HOME_LAYOUT)).toBe(false);
    expect(compactLayout(DEFAULT_HOME_LAYOUT)).toEqual(
      [...DEFAULT_HOME_LAYOUT].sort((a, b) => a.y - b.y || a.x - b.x)
    );
  });

  it('moving a block onto another pushes the other one down', () => {
    const items = moveItem(DEFAULT_HOME_LAYOUT, 'overdue-actions', {
      x: 0,
      y: 0,
    });

    expect(byId(items, 'overdue-actions')).toMatchObject({ x: 0, y: 0 });
    expect(overlaps(items)).toBe(false);
  });

  it('closes the gap a block leaves when it is removed', () => {
    const items = removeItem(DEFAULT_HOME_LAYOUT, 'today-appointments');

    expect(byId(items, 'open-conversations').y).toBe(2);
  });

  it('never shrinks a block below what its content needs', () => {
    const kpi = resizeItem(DEFAULT_HOME_LAYOUT, 'kpi-actions', { w: 1, h: 1 });
    const list = resizeItem(DEFAULT_HOME_LAYOUT, 'overdue-actions', {
      w: 1,
      h: 1,
    });

    expect(byId(kpi, 'kpi-actions')).toMatchObject({ w: 2, h: 2 });
    expect(byId(list, 'overdue-actions')).toMatchObject({ w: 4, h: 3 });
  });

  it('keeps a block inside the twelve columns', () => {
    const wide = resizeItem(DEFAULT_HOME_LAYOUT, 'kpi-payments', {
      w: 20,
      h: 2,
    });
    const right = moveItem(DEFAULT_HOME_LAYOUT, 'kpi-actions', { x: 40, y: 0 });

    expect(byId(wide, 'kpi-payments')).toMatchObject({ x: 0, w: 12 });
    expect(byId(right, 'kpi-actions').x).toBe(9);
  });

  it('adds a block at the end, at the size it has in the default Home', () => {
    const without = removeItem(DEFAULT_HOME_LAYOUT, 'overdue-payments');
    const items = addItem(without, 'overdue-payments');
    const bottom = Math.max(...without.map(item => item.y + item.h));

    expect(byId(items, 'overdue-payments')).toMatchObject({
      w: 5,
      h: 3,
    });
    expect(byId(items, 'overdue-payments').y).toBeLessThanOrEqual(bottom);
    expect(addItem(items, 'overdue-payments')).toBe(items);
  });

  it('renames a block, and an empty name goes back to the original', () => {
    const named = renameItem(DEFAULT_HOME_LAYOUT, 'kpi-actions', '  Atrasos  ');
    expect(byId(named, 'kpi-actions').title).toBe('Atrasos');

    const cleared = renameItem(named, 'kpi-actions', ' ');
    expect(byId(cleared, 'kpi-actions')).not.toHaveProperty('title');
  });

  describe('what is read back', () => {
    it('refuses anything that is not the documented shape', () => {
      expect(sanitizeLayout(null)).toBeNull();
      expect(sanitizeLayout({ version: 2, items: [] })).toBeNull();
      expect(
        sanitizeLayout(layout([{ id: 'unknown', x: 0, y: 0, w: 3, h: 2 }]))
      ).toBeNull();
      expect(
        sanitizeLayout(
          layout([
            { id: 'kpi-actions', x: 0, y: 0, w: 3, h: 2 },
            { id: 'kpi-actions', x: 3, y: 0, w: 3, h: 2 },
          ])
        )
      ).toBeNull();
      expect(
        sanitizeLayout(
          layout([{ id: 'kpi-actions', x: '0', y: 0, w: 3, h: 2 }])
        )
      ).toBeNull();
    });

    it("prefers the person's layout, then the team's, then the default", () => {
      const mine = layout([{ id: 'kpi-actions', x: 0, y: 0, w: 3, h: 2 }]);
      const team = layout([{ id: 'kpi-agenda', x: 0, y: 0, w: 3, h: 2 }]);

      expect(resolveLayout({ user: mine, account: team })[0].id).toBe(
        'kpi-actions'
      );
      expect(resolveLayout({ account: team })[0].id).toBe('kpi-agenda');
      expect(resolveLayout({ user: { version: 9 }, account: null })).toEqual(
        DEFAULT_HOME_LAYOUT
      );
    });

    it('hides a block whose module is off and closes its space', () => {
      const shown = visibleLayout(DEFAULT_HOME_LAYOUT, [
        'kpi-conversations',
        'open-conversations',
      ]);

      expect(shown.map(item => item.id)).toEqual([
        'kpi-conversations',
        'open-conversations',
      ]);
      expect(byId(shown, 'open-conversations').y).toBe(2);
    });

    it('saves the hidden blocks where they were', () => {
      const available = ['kpi-conversations'];
      const edited = [{ id: 'kpi-conversations', x: 0, y: 0, w: 6, h: 2 }];
      const saved = layoutToSave(edited, DEFAULT_HOME_LAYOUT, available);

      expect(saved.version).toBe(1);
      expect(byId(saved.items, 'kpi-conversations').w).toBe(6);
      expect(byId(saved.items, 'overdue-payments')).toEqual(
        byId(DEFAULT_HOME_LAYOUT, 'overdue-payments')
      );
    });
  });

  it('adds an insight, which is not in the default Home, at an indicator size', () => {
    const items = addItem(DEFAULT_HOME_LAYOUT, 'kpi-waiting-24h');

    expect(byId(items, 'kpi-waiting-24h')).toMatchObject({ w: 3, h: 2 });
  });

  it('fills the first gap a block fits in before growing the Home', () => {
    const withGap = removeItem(DEFAULT_HOME_LAYOUT, 'kpi-agenda').map(item =>
      item.id === 'kpi-payments' ? { ...item, x: 9 } : item
    );
    const items = addItem(withGap, 'kpi-waiting-24h');

    expect(byId(items, 'kpi-waiting-24h')).toMatchObject({ x: 6, y: 0 });
  });
});
