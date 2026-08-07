import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';
import { Login } from '@components/ui';

const TEST_EMAIL = process.env.TEST_USER_EMAIL || 'admin@chatwoot.com';
const TEST_PASSWORD = process.env.TEST_USER_PASSWORD || 'Password123@#';
const APPOINTMENT_CONTACT = process.env.CALENDAR_E2E_APPOINTMENT_CONTACT;

test.describe('Calendar workspace', () => {
  test.skip(
    !process.env.CALENDAR_E2E,
    'Set CALENDAR_E2E=1 against an account with an active procedure, resource and appointment.'
  );

  const openCalendar = async (page: Page) => {
    const accountMatch = page.url().match(/\/accounts\/(\d+)/);
    const accountId = accountMatch?.[1];
    expect(accountId).toBeTruthy();

    await page.goto(`/app/accounts/${accountId}/calendar`);
    await expect(page.getByTestId('calendar-workspace')).toBeVisible();
  };

  test.beforeEach(async ({ page }) => {
    const login = new Login(page);
    await login.navigate();
    await Promise.all([
      page.waitForURL(/\/app\/accounts\/\d+\//, { waitUntil: 'commit' }),
      login.login(TEST_EMAIL, TEST_PASSWORD),
    ]);
  });

  test('opens scheduling with keyboard-accessible calendar controls', async ({
    page,
  }) => {
    await openCalendar(page);

    const search = page.locator('#calendar-search');
    await search.focus();
    await expect(search).toBeFocused();

    const settings = page.getByTestId('calendar-open-settings');
    await expect(settings).toHaveAccessibleName(/.+/);

    const newAppointment = page.getByTestId('calendar-new-appointment');
    await newAppointment.focus();
    await page.keyboard.press('Enter');
    const bookingDialog = page.getByRole('dialog');
    await expect(bookingDialog).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(bookingDialog).toBeHidden();
  });

  test('filters the schedule and switches between day and week', async ({
    page,
  }) => {
    await openCalendar(page);

    await page
      .getByLabel(/Filter by professional or resource/i)
      .selectOption({ label: 'Dra. E2E' });
    await page.locator('#calendar-search').fill('Paciente E2E');
    await expect(page.getByTestId('calendar-appointment').first()).toBeVisible();

    await page.getByRole('button', { name: 'Day', exact: true }).click();
    await expect(page.getByTestId('calendar-day-column')).toHaveCount(1);
    await page.getByRole('button', { name: 'Week', exact: true }).click();
    await expect(page.getByTestId('calendar-day-column')).toHaveCount(7);
  });

  test('creates an appointment from a free suggested time', async ({ page }) => {
    await openCalendar(page);

    await page.getByTestId('calendar-new-appointment').click();
    const bookingDialog = page.getByRole('dialog');
    await expect(bookingDialog).toBeVisible();

    const contactSearch = bookingDialog.getByTestId(
      'calendar-appointment-contact-search'
    );
    await contactSearch.fill('Paciente E2E');
    await bookingDialog.getByRole('button', { name: 'Paciente E2E' }).click();

    await bookingDialog
      .getByTestId('kanban-calendar-procedure')
      .selectOption({ label: 'Consulta E2E' });
    await bookingDialog
      .getByTestId('kanban-calendar-resource')
      .selectOption({ label: 'Dra. E2E' });
    const schedulingDate = await page.evaluate(() => {
      const date = new Date();
      date.setDate(date.getDate() + 1);
      return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}T09:00`;
    });
    await bookingDialog
      .getByTestId('kanban-calendar-starts-at')
      .fill(schedulingDate);

    await expect(
      bookingDialog.getByTestId('calendar-availability-slot').first()
    ).toBeVisible();
    await bookingDialog
      .getByTestId('calendar-availability-slot')
      .first()
      .click();

    const confirm = bookingDialog.getByTestId('calendar-confirm-booking');
    await expect(confirm).toBeEnabled();
    await confirm.click();
    await expect(bookingDialog).toBeHidden();
  });

  test('opens a scheduled appointment and preserves focus when closing', async ({
    page,
  }) => {
    test.skip(!APPOINTMENT_CONTACT, 'Set CALENDAR_E2E_APPOINTMENT_CONTACT.');
    await openCalendar(page);

    const appointment = page
      .getByTestId('calendar-appointment')
      .filter({ hasText: APPOINTMENT_CONTACT })
      .first();
    await expect(appointment).toBeVisible();
    await appointment.click();

    const detailsDialog = page.getByRole('dialog');
    await expect(detailsDialog).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(detailsDialog).toBeHidden();
    await expect(appointment).toBeFocused();
  });

  test('reschedules an appointment using another free time', async ({ page }) => {
    test.skip(!APPOINTMENT_CONTACT, 'Set CALENDAR_E2E_APPOINTMENT_CONTACT.');
    await openCalendar(page);

    const appointment = page
      .getByTestId('calendar-appointment')
      .filter({ hasText: APPOINTMENT_CONTACT })
      .first();
    await appointment.click();

    const detailsDialog = page.getByRole('dialog');
    await detailsDialog.getByRole('button', { name: 'Reschedule' }).click();
    const rescheduleDate = await page.evaluate(() => {
      const date = new Date();
      date.setDate(date.getDate() + 2);
      return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}T09:00`;
    });
    await detailsDialog.locator('input[type="datetime-local"]').fill(rescheduleDate);
    await expect(
      detailsDialog.getByTestId('reschedule-available-slot').first()
    ).toBeVisible();
    await detailsDialog
      .getByTestId('reschedule-available-slot')
      .first()
      .click();
    await detailsDialog.getByRole('button', { name: 'Save reschedule' }).click();

    await expect(
      detailsDialog.getByRole('button', { name: 'Reschedule' })
    ).toBeVisible();
  });

  test('cancels an appointment with a reason', async ({ page }) => {
    test.skip(!APPOINTMENT_CONTACT, 'Set CALENDAR_E2E_APPOINTMENT_CONTACT.');
    await openCalendar(page);

    const appointment = page
      .getByTestId('calendar-appointment')
      .filter({ hasText: APPOINTMENT_CONTACT })
      .first();
    await appointment.click();

    const detailsDialog = page.getByRole('dialog');
    await detailsDialog.locator('input[type="text"]').fill('Cancelamento E2E');
    await detailsDialog.getByRole('button', { name: 'Cancel' }).click();

    await expect(
      detailsDialog.getByRole('button', { name: 'Cancel' })
    ).toBeHidden();
  });
});
