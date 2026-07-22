import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { Login } from '@components/ui';

const TEST_EMAIL = process.env.TEST_USER_EMAIL || 'admin@chatwoot.com';
const TEST_PASSWORD = process.env.TEST_USER_PASSWORD || 'Password123@#';

test.describe('Kanban accessibility and responsive workspace', () => {
  test.skip(
    !process.env.KANBAN_E2E,
    'Set KANBAN_E2E=1 to run against an environment with a seeded Kanban board.'
  );

  const openFirstBoard = async (page: Page) => {
    const accountMatch = page.url().match(/\/accounts\/(\d+)/);
    const accountId = accountMatch?.[1];
    expect(accountId).toBeTruthy();

    await page.goto(`/app/accounts/${accountId}/kanban`);
    const board = page.getByTestId('overview-board-card').first();
    await expect(board).toBeVisible();
    await board.click();
    await expect(page.getByTestId('kanban-workspace-header')).toBeVisible();
  };

  test.beforeEach(async ({ page }) => {
    const login = new Login(page);
    await login.navigate();
    await login.login(TEST_EMAIL, TEST_PASSWORD);
  });

  test('exposes the main workflow through accessible controls and keyboard focus', async ({
    page,
  }) => {
    await openFirstBoard(page);

    const search = page.getByTestId('kanban-search-input');
    await search.focus();
    await expect(search).toBeFocused();
    await page.keyboard.press('Tab');
    await expect(page.locator(':focus')).toHaveAccessibleName(/.+/);

    const filterToggle = page.getByTestId('kanban-toggle-filters');
    await expect(filterToggle).toHaveAccessibleName(/.+/);
    await filterToggle.click();
    await expect(page.getByTestId('kanban-filter-panel')).toBeVisible();

    const filterControls = page
      .getByTestId('kanban-filter-panel')
      .locator('button, input, select');
    await expect(filterControls.first()).toBeVisible();
    await filterControls.first().focus();
    await expect(filterControls.first()).toBeFocused();
  });

  test('keeps the opportunity drawer announced and closable with Escape', async ({
    page,
  }) => {
    await openFirstBoard(page);

    const openDetails = page.getByTestId('kanban-card-open-details').first();
    await expect(openDetails).toBeVisible();
    await expect(openDetails).toHaveAttribute('aria-label', /.+/);
    await openDetails.click();

    const drawer = page.getByTestId('kanban-opportunity-drawer');
    await expect(drawer).toBeVisible();
    await expect(drawer).toHaveAttribute('role', 'dialog');
    await expect(drawer).toHaveAttribute('aria-modal', 'true');
    await expect(drawer).toHaveAttribute('aria-label', /.+/);
    await expect(drawer.getByRole('tablist')).toBeVisible();

    await page.keyboard.press('Escape');
    await expect(drawer).toBeHidden();
    await expect(openDetails).toBeFocused();
  });

  test('keeps the workspace header inside the mobile viewport', async ({
    page,
  }) => {
    await openFirstBoard(page);

    const header = page.getByTestId('kanban-workspace-header');
    await expect(header).toBeVisible();
    await expect
      .poll(() =>
        header.evaluate(element => element.scrollWidth <= element.clientWidth)
      )
      .toBe(true);

    const accessibleButtons = header.getByRole('button');
    await expect(accessibleButtons.first()).toBeVisible();
    await expect(accessibleButtons.first()).toHaveAccessibleName(/.+/);
  });
});
