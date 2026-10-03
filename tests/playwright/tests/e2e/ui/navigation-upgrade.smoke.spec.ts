import { expect, test, type Request } from '@playwright/test';

test('keeps Pipeline and the sidebar through click navigation after an upstream upgrade', async ({
  page,
}, testInfo) => {
  const pageErrors: string[] = [];
  const applicationErrors: string[] = [];
  const failedApiResponses: string[] = [];
  const pendingApiRequests = new Set<Request>();
  const isApiUrl = (url: string) => /\/api\/v[12]\//.test(url);
  page.on('request', request => {
    if (isApiUrl(request.url())) pendingApiRequests.add(request);
  });
  page.on('requestfinished', request => pendingApiRequests.delete(request));
  page.on('requestfailed', request => {
    pendingApiRequests.delete(request);
    if (isApiUrl(request.url())) {
      failedApiResponses.push(
        `Network failure ${new URL(request.url()).pathname}`
      );
    }
  });
  page.on('pageerror', error => pageErrors.push(error.message));
  page.on('console', message => {
    if (
      message.type() === 'error' &&
      !message.text().startsWith('Failed to load resource:')
    ) {
      applicationErrors.push(message.text());
    }
  });
  page.on('response', response => {
    if (isApiUrl(response.url()) && response.status() >= 400) {
      failedApiResponses.push(
        `${response.status()} ${new URL(response.url()).pathname}`
      );
    }
  });

  await page.goto('/app/login');
  const inputs = page.locator('form input');
  await inputs
    .nth(0)
    .fill(process.env.TEST_USER_EMAIL || 'navigation-smoke@raevo.test');
  await inputs
    .nth(1)
    .fill(process.env.TEST_USER_PASSWORD || 'NavigationSmoke1!');
  await page
    .getByRole('button', { name: /entrar|log ?in|sign ?in/i })
    .first()
    .click();
  await page.waitForURL(/\/app\/accounts\/\d+\//);
  await expect(page).toHaveTitle(/^\(1\) /);

  const sidebar = page.locator('aside[aria-expanded]');
  await expect(sidebar).toBeVisible();
  const expand = sidebar.getByRole('button', { name: /expandir/i });
  if (await expand.isVisible()) await expand.click();

  for (const [label, destination] of [
    ['Inicio', /\/home$/],
    ['Agenda', /\/calendar$/],
    ['Marketing', /\/marketing$/],
    ['Financeiro', /\/finance$/],
    ['Formularios', /\/forms$/],
    ['Contatos', /\/contacts/],
    ['Relatorios', /\/reports/],
    ['Campanhas', /\/campaigns/],
    ['Configuracoes', /\/settings/],
    ['Conversas', /\/dashboard/],
  ] as const) {
    const names: Record<string, RegExp> = {
      Inicio: /^In[ií]cio$/,
      Formularios: /^Formul[aá]rios$/,
      Relatorios: /^Relat[oó]rios$/,
      Configuracoes: /^Configura[cç][oõ]es$/,
    };
    await sidebar
      .getByTitle(names[label] || label, { exact: true })
      .filter({ visible: true })
      .first()
      .click();
    await expect(page).toHaveURL(destination);
    await expect(sidebar).toBeVisible();
    await expect(
      sidebar.getByTitle('Pipeline', { exact: true }).first()
    ).toBeVisible();
    await expect.poll(() => pendingApiRequests.size).toBe(0);
    await expect(
      page.getByText(/^Carregando(?:\s|\.|$)/i).filter({ visible: true })
    ).toHaveCount(0);
    await testInfo.attach(label, {
      body: await page.screenshot({ animations: 'disabled' }),
      contentType: 'image/png',
    });
    expect(pageErrors, `Unhandled errors on ${label}`).toEqual([]);
  }

  const currentUrl = page.url();
  await sidebar.getByTitle('Pipeline', { exact: true }).first().click();
  await expect(page).toHaveURL(currentUrl);
  await sidebar.getByTitle('Smoke pipeline', { exact: true }).click();
  await expect(page).toHaveURL(/\/kanban\/\d+$/);
  await expect(sidebar).toBeVisible();
  await expect(
    page.getByText('Oportunidade smoke', { exact: true }).first()
  ).toBeVisible();
  await testInfo.attach('Pipeline', {
    body: await page.screenshot({ animations: 'disabled' }),
    contentType: 'image/png',
  });

  await sidebar
    .getByTitle(/^Contatos$/, { exact: true })
    .filter({ visible: true })
    .first()
    .click();
  await page.getByText('Pedro Raevo Smoke', { exact: true }).first().click();
  await expect(
    page.locator('input[size]').filter({ visible: true }).first()
  ).toBeVisible();
  await expect(page.getByPlaceholder(/WhatsApp/i)).toHaveValue('pedrosmoke');
  await testInfo.attach('Contato com perfil WhatsApp', {
    body: await page.screenshot({ animations: 'disabled' }),
    contentType: 'image/png',
  });

  await sidebar.getByTitle('Conversas', { exact: true }).first().click();
  const inbox = sidebar.getByTitle('Smoke API', { exact: true }).first();
  if (!(await inbox.isVisible())) {
    await sidebar
      .getByRole('button', { name: 'Canais', exact: true })
      .first()
      .click();
  }
  const image = inbox.locator('img');
  await expect(image).toBeVisible();
  await expect
    .poll(() =>
      image.evaluate((element: HTMLImageElement) => element.naturalWidth)
    )
    .toBeGreaterThan(0);
  await expect.poll(() => pendingApiRequests.size).toBe(0);
  await expect(
    page.getByText(/^Carregando conversas/i).filter({ visible: true })
  ).toHaveCount(0);
  await testInfo.attach('Caixa com imagem', {
    body: await page.screenshot({ animations: 'disabled' }),
    contentType: 'image/png',
  });

  expect(pageErrors).toEqual([]);
  expect(applicationErrors).toEqual([]);
  expect(failedApiResponses).toEqual([]);
});
