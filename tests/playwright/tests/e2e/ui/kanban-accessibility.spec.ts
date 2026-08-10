import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { Login } from '@components/ui';

const TEST_EMAIL = process.env.TEST_USER_EMAIL || 'admin@chatwoot.com';
const TEST_PASSWORD = process.env.TEST_USER_PASSWORD || 'Password123@#';
const TEST_BOARD_ID = process.env.KANBAN_E2E_BOARD_ID;

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
    const board = TEST_BOARD_ID
      ? page.locator(
          `[data-testid="overview-board-card"][data-kanban-board-id="${TEST_BOARD_ID}"]`
        )
      : page.getByTestId('overview-board-card').first();
    await expect(board).toBeVisible();
    await board.click();
    await expect(page.getByTestId('kanban-workspace-header')).toBeVisible();
  };

  const openBoardAutomations = async (page: Page) => {
    await page.getByTestId('kanban-board-actions-menu').click();
    const automations = page.getByTestId('kanban-board-automations-button');
    await expect(automations).toBeVisible();
    await automations.click();
  };

  test.beforeEach(async ({ page }) => {
    const login = new Login(page);
    await login.navigate();
    await Promise.all([
      page.waitForURL(/\/app\/accounts\/\d+\//, { waitUntil: 'commit' }),
      login.login(TEST_EMAIL, TEST_PASSWORD),
    ]);
  });

  test('exposes the main workflow through accessible controls and keyboard focus', async ({
    page,
  }) => {
    await openFirstBoard(page);

    const search = page.getByTestId('kanban-search-input');
    await search.focus();
    await expect(search).toBeFocused();
    await expect(search).toHaveAttribute('aria-controls', 'kanban-filter-panel');
    await expect(search).toHaveAttribute('aria-expanded', 'true');
    await expect(page.getByTestId('kanban-filter-panel')).toBeVisible();
    await page.keyboard.press('Tab');
    await expect(page.locator(':focus')).toHaveAccessibleName(/.+/);

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
    await page.setViewportSize({ width: 320, height: 720 });
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

  test('keeps the board actions usable at tablet width', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await openFirstBoard(page);

    const header = page.getByTestId('kanban-workspace-header');
    const search = page.getByTestId('kanban-search-input');

    await expect(header).toBeVisible();
    await expect
      .poll(() =>
        header.evaluate(element => element.scrollWidth <= element.clientWidth)
      )
      .toBe(true);
    await expect(search).toBeVisible();
    await search.focus();
    await page.keyboard.press('Enter');
    await expect(page.getByTestId('kanban-filter-panel')).toBeVisible();

    await page.getByTestId('kanban-board-actions-menu').click();
    await expect(
      page.getByTestId('kanban-board-automations-button')
    ).toBeVisible();
  });

  test('opens the visual workflow canvas with a keyboard-dismissible inspector', async ({
    page,
  }) => {
    await openFirstBoard(page);

    await openBoardAutomations(page);
    await expect(page.getByTestId('kanban-automations-workspace')).toBeVisible();
    await page.getByTestId('kanban-automations-new-flow').click();

    const builder = page.getByTestId('kanban-workflow-builder');
    await expect(builder).toBeVisible();
    await expect(page.getByTestId('kanban-workflow-canvas')).toBeVisible();
    const mobilePaletteButton = page.getByTestId(
      'kanban-workflow-open-mobile-palette'
    );
    const isMobilePalette = await mobilePaletteButton.isVisible();
    if (isMobilePalette) {
      await mobilePaletteButton.click();
    } else {
      await page.getByTestId('kanban-workflow-add-node').click();
    }

    const palette = isMobilePalette
      ? page.getByTestId('kanban-workflow-mobile-palette')
      : page.locator('[data-testid="kanban-workflow-palette"]:visible');
    await expect(palette).toBeVisible();
    await palette.getByTestId('kanban-workflow-palette-node').first().click();

    const inspector = page.getByTestId('kanban-workflow-node-drawer');
    await expect(inspector).toBeVisible();
    await expect(inspector).toHaveAttribute('role', 'dialog');
    await page.keyboard.press('Escape');
    await expect(inspector).toBeHidden();
    await expect(builder).toBeFocused();

    const canvasNode = page
      .getByTestId('kanban-workflow-node-card')
      .first();
    await canvasNode.focus();
    await page.keyboard.press('Enter');
    await expect(inspector).toBeVisible();

    const focusable = inspector.locator(
      'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])'
    );
    const firstControl = focusable.first();
    const lastControl = focusable.last();

    await lastControl.focus();
    await page.keyboard.press('Tab');
    await expect(firstControl).toBeFocused();

    await firstControl.focus();
    await page.keyboard.press('Shift+Tab');
    await expect(lastControl).toBeFocused();

    const configureTab = page.getByTestId(
      'kanban-workflow-inspector-tab-configure'
    );
    await configureTab.focus();
    await page.keyboard.press('ArrowRight');
    await expect(
      page.getByTestId('kanban-workflow-inspector-tab-test')
    ).toHaveAttribute('aria-selected', 'true');
  });

  test('opens and closes the categorized workflow palette on mobile', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 320, height: 720 });
    await openFirstBoard(page);

    await openBoardAutomations(page);
    await page.getByTestId('kanban-automations-new-flow').click();

    const mobilePaletteButton = page.getByTestId(
      'kanban-workflow-open-mobile-palette'
    );
    await expect(mobilePaletteButton).toBeVisible();
    await mobilePaletteButton.click();

    const palette = page.getByTestId('kanban-workflow-mobile-palette');
    await expect(palette).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(palette).toBeHidden();
    await expect(mobilePaletteButton).toBeFocused();
  });
});
