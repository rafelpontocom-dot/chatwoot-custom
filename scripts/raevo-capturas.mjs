// Passo 5 da porta visual: capturas de desktop a 1280px das telas que a caixa de
// Consultório e a fila de indicadores tocaram. Corre contra a aplicação real, com
// dados semeados — não é uma maquete.
import { chromium } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const BASE = 'http://127.0.0.1:3000';
const CONTA = 1;
const QUADRO = process.env.QUADRO || '1';
const SAIDA = process.env.SAIDA || 'tmp/capturas';
const TEMA = process.env.TEMA || 'light';

const TELAS = [
  ['inicio', `/app/accounts/${CONTA}/home`],
  ['pipeline', `/app/accounts/${CONTA}/kanban/${QUADRO}`],
  ['funil', `/app/accounts/${CONTA}/kanban/${QUADRO}/funnel`],
  ['financeiro', `/app/accounts/${CONTA}/finance`],
  ['agenda', `/app/accounts/${CONTA}/calendar`],
  ['ia', `/app/accounts/${CONTA}/raevo-ai`],
];

mkdirSync(SAIDA, { recursive: true });

// `--no-proxy-server`: o proxy de egresso desta máquina não serve 127.0.0.1.
const navegador = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium',
  args: ['--no-proxy-server'],
});
const contexto = await navegador.newContext({
  viewport: { width: 1280, height: 900 },
  deviceScaleFactor: 1,
  colorScheme: TEMA === 'dark' ? 'dark' : 'light',
});
const pagina = await contexto.newPage();

const erros = [];
pagina.on('console', m => {
  if (m.type() === 'error') erros.push(m.text().slice(0, 200));
});
pagina.on('pageerror', e =>
  erros.push(`pageerror: ${String(e).slice(0, 200)}`)
);

// --- entrar ---
await pagina.goto(`${BASE}/app/login`, { waitUntil: 'load', timeout: 90000 });
// Os campos não declaram type=email/password: usa a ordem, e o botão pelo texto.
const campos = pagina.locator('form input');
await campos.nth(0).fill('john@acme.inc');
await campos.nth(1).fill('Password1!');
await pagina
  .getByRole('button', { name: /entrar|log ?in|sign ?in/i })
  .first()
  .click();
await pagina.waitForURL(/\/app\/accounts\//, { timeout: 60000 });
console.log('entrou:', pagina.url());

for (const [nome, caminho] of TELAS) {
  erros.length = 0;
  try {
    await pagina.goto(`${BASE}${caminho}`, {
      waitUntil: 'load',
      timeout: 90000,
    });
    // Os indicadores chegam por pedido próprio; espera pela rede e um pouco mais.
    await pagina.waitForTimeout(3500);
    const ficheiro = `${SAIDA}/${TEMA}-${nome}.png`;
    await pagina.screenshot({ path: ficheiro });
    const texto = (await pagina.locator('body').innerText())
      .replace(/\s+/g, ' ')
      .slice(0, 220);
    console.log(`\n== ${nome} (${caminho})`);
    console.log(`   ficheiro: ${ficheiro}`);
    console.log(`   texto: ${texto}`);
    if (erros.length)
      console.log(`   ERROS DE CONSOLA: ${erros.slice(0, 3).join(' | ')}`);
  } catch (e) {
    console.log(`\n== ${nome}: FALHOU -> ${String(e).slice(0, 200)}`);
  }
}

await navegador.close();
