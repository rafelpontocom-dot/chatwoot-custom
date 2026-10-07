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
    if (label === 'Inicio') {
      await page.setViewportSize({ width: 1440, height: 500 });
      const scrollArea = page
        .locator('div.overflow-y-auto')
        .filter({ has: page.locator('main') })
        .last();
      await expect
        .poll(() =>
          scrollArea.evaluate(
            element => element.scrollHeight - element.clientHeight
          )
        )
        .toBeGreaterThan(0);
      await scrollArea.evaluate(element => {
        element.scrollTop = element.scrollHeight;
      });
      await expect
        .poll(() => scrollArea.evaluate(element => element.scrollTop))
        .toBeGreaterThan(0);
      await testInfo.attach('Inicio com rolagem', {
        body: await page.screenshot({ animations: 'disabled' }),
        contentType: 'image/png',
      });
      await page.setViewportSize({ width: 1440, height: 900 });
    }
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

  await page.getByText('Oportunidade smoke', { exact: true }).first().click();
  const completedResponse = page.waitForResponse(
    response =>
      /\/cards\/by_id\/\d+$/.test(response.url()) &&
      response.request().method() === 'PATCH'
  );
  await page.getByTestId('kanban-opportunity-complete-next-action').click();
  const completion = await completedResponse;
  expect(completion.status()).toBe(200);
  expect(completion.request().postDataJSON().card).toMatchObject({
    complete_next_action: true,
  });
  expect(completion.request().postDataJSON().card).not.toHaveProperty(
    'next_action_at'
  );
  const completedCard = await completion.json();
  expect(completedCard).toMatchObject({
    next_action_type: null,
    next_action_at: null,
    next_action_note: null,
  });
  expect(completedCard.next_action_history.at(-1)).toMatchObject({
    type: 'Ligar',
    scheduled_at: '2026-10-07T13:30:47.123Z',
    note: 'Acao para validar conclusao',
  });
  await page.getByTestId('kanban-opportunity-close').click();

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

  const compactLayoutButton = page
    .getByRole('button')
    .filter({ has: page.locator('.i-lucide-arrow-left-to-line') });
  if (await compactLayoutButton.isVisible()) {
    await compactLayoutButton.click();
    await expect(page.locator('.conversation.grid')).toHaveCount(0);
    await expect.poll(() => pendingApiRequests.size).toBe(0);
  }
  for (const layout of ['compacto', 'expandido']) {
    if (layout === 'expandido') {
      await page
        .getByRole('button')
        .filter({ has: page.locator('.i-lucide-arrow-right-to-line') })
        .click();
      await expect(page.locator('.conversation.grid').first()).toBeVisible();
    }
    for (const [tab, contactName, count] of [
      [/^Minhas/, 'Pedro Raevo Assigned Smoke', 1],
      [/^Não atribuídas/, 'Pedro Raevo Smoke', 1],
      [/^Todos/, 'Pedro Raevo Smoke', 2],
    ] as const) {
      await page
        .locator('a')
        .filter({ hasText: tab })
        .filter({ visible: true })
        .click();
      const rows = page.locator('.conversation');
      await expect(rows).toHaveCount(count);
      await expect(rows.filter({ hasText: contactName })).toBeVisible();
      const channelImages = rows.locator('[title="Smoke API"] img');
      await expect(channelImages).toHaveCount(count);
      for (const channelImage of await channelImages.all()) {
        await expect(channelImage).toBeVisible();
        await expect
          .poll(() =>
            channelImage.evaluate(
              (element: HTMLImageElement) => element.naturalWidth
            )
          )
          .toBeGreaterThan(0);
      }
      await expect.poll(() => pendingApiRequests.size).toBe(0);
      await testInfo.attach(`Conversas ${tab.source} ${layout}`, {
        body: await page.screenshot({ animations: 'disabled' }),
        contentType: 'image/png',
      });
    }
  }

  // Use the real settings screen and API, not an in-memory order assertion.
  await expect.poll(() => pendingApiRequests.size).toBe(0);
  await sidebar
    .getByTitle(/^Configurações$/, { exact: true })
    .filter({ visible: true })
    .first()
    .click();
  await sidebar
    .getByTitle(/^Etiquetas$/, { exact: true })
    .filter({ visible: true })
    .first()
    .click();
  const labelRows = page.locator('tbody tr');
  await expect(labelRows).toHaveCount(2);
  await expect(labelRows.first()).toContainText('alpha-smoke');
  const reorderResponse = page.waitForResponse(
    response =>
      /\/labels\/reorder$/.test(response.url()) &&
      response.request().method() === 'POST'
  );
  await labelRows
    .filter({ hasText: 'zulu-smoke' })
    .getByRole('button', { name: 'Mover para cima', exact: true })
    .click();
  expect((await reorderResponse).status()).toBe(200);
  await expect(labelRows.first()).toContainText('zulu-smoke');
  await page.reload();
  await expect(labelRows.first()).toContainText('zulu-smoke');
  await testInfo.attach('Etiquetas com ordem persistida', {
    body: await page.screenshot({ animations: 'disabled' }),
    contentType: 'image/png',
  });

  const operationalMarketing = sidebar.locator(
    'nav > ul > li > a[title="Marketing"]'
  );
  await expect(operationalMarketing).toBeVisible();
  await operationalMarketing.click();
  await expect(
    page.locator('[data-testid="marketing-capture-rate"]')
  ).toBeVisible();
  await page.getByTestId('marketing-toggle-settings').click();
  await page.getByTestId('marketing-toggle-module').uncheck();
  await expect(operationalMarketing).toHaveCount(0);
  const settingsMarketing = sidebar.getByTitle('Marketing', { exact: true });
  if (!(await settingsMarketing.isVisible())) {
    await sidebar
      .getByTitle(/^Configurações$/, { exact: true })
      .filter({ visible: true })
      .first()
      .click();
  }
  await settingsMarketing.click();
  await expect(page).toHaveURL(/\/marketing$/);
  await page.reload();
  await expect(page.getByTestId('marketing-capture-rate')).toHaveCount(0);
  await expect(page.getByTestId('marketing-toggle-settings')).toBeVisible();
  await page.getByTestId('marketing-toggle-settings').click();
  await page.getByTestId('marketing-toggle-module').check();
  await sidebar.getByTitle('Pipeline', { exact: true }).first().click();
  await expect(operationalMarketing).toBeVisible();
  await operationalMarketing.click();
  const marketingSettings = page.getByTestId('marketing-toggle-settings');
  if ((await marketingSettings.getAttribute('aria-pressed')) === 'true') {
    await marketingSettings.click();
  }
  await expect(page.getByTestId('marketing-capture-rate')).toBeVisible();
  await expect.poll(() => pendingApiRequests.size).toBe(0);
  await testInfo.attach('Marketing ligado e reativado', {
    body: await page.screenshot({ animations: 'disabled' }),
    contentType: 'image/png',
  });

  expect(pageErrors).toEqual([]);
  expect(applicationErrors).toEqual([]);
  expect(failedApiResponses).toEqual([]);
});
