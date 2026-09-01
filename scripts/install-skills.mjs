#!/usr/bin/env node
/**
 * Instala as skills declaradas em `skills-lock.json`.
 *
 * O lock estava versionado desde agosto e não havia nada que o lesse: as skills
 * viviam só na máquina de quem as tinha buscado à mão, e o AGENTS.md exigia
 * cinco que ninguém conseguia carregar. Isto fecha esse buraco — `.claude/` é
 * ignorado pelo git de propósito, portanto o lock é a única coisa partilhada e
 * tem de bastar para reconstruir o conjunto.
 *
 * Uso:  node scripts/install-skills.mjs [nome ...]
 * Requer o `gh` autenticado (usa a API do GitHub para os tarballs).
 */
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const RAIZ = path.resolve(import.meta.dirname, '..');
const DESTINO = path.join(RAIZ, '.claude', 'skills');
const lock = JSON.parse(
  fs.readFileSync(path.join(RAIZ, 'skills-lock.json'), 'utf8')
);

const pedidos = process.argv.slice(2);
const escolhidas = Object.entries(lock.skills).filter(
  ([nome]) => pedidos.length === 0 || pedidos.includes(nome)
);

const gh = (args, opcoes = {}) =>
  execFileSync('gh', args, { maxBuffer: 256 * 1024 * 1024, ...opcoes });

/**
 * O Claude Code identifica a skill pela pasta. Quando o `name:` do frontmatter
 * diverge — o `ui-patterns` do repo Frappe instalado como `frappe-ui-patterns`,
 * por exemplo — a skill regista-se com o nome errado e quem a invoca pelo nome
 * do AGENTS.md nunca a encontra.
 */
function alinharNome(ficheiro, nome) {
  const texto = fs.readFileSync(ficheiro, 'utf8');
  const corrigido = texto.replace(/^name:.*$/m, `name: ${nome}`);
  if (corrigido === texto) return false;

  fs.writeFileSync(ficheiro, corrigido);
  return true;
}

let falhas = 0;
for (const [nome, entrada] of escolhidas) {
  const { source, skillPath } = entrada;
  const subdir = path.dirname(skillPath);
  const temporario = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-'));

  try {
    const branch = gh(['api', `repos/${source}`, '--jq', '.default_branch'], {
      encoding: 'utf8',
    }).trim();
    const tarball = path.join(temporario, 'skill.tar.gz');
    fs.writeFileSync(tarball, gh(['api', `repos/${source}/tarball/${branch}`]));

    const primeira = execFileSync('tar', ['tzf', tarball], { encoding: 'utf8' });
    const prefixo = primeira.split('\n')[0].split('/')[0];
    execFileSync('tar', ['xzf', tarball, '-C', temporario, `${prefixo}/${subdir}`]);

    const pasta = path.join(DESTINO, nome);
    fs.rmSync(pasta, { recursive: true, force: true });
    fs.mkdirSync(pasta, { recursive: true });
    fs.cpSync(path.join(temporario, prefixo, subdir), pasta, { recursive: true });

    const skill = path.join(pasta, 'SKILL.md');
    if (!fs.existsSync(skill)) throw new Error(`sem SKILL.md em ${subdir}`);

    const renomeada = alinharNome(skill, nome);
    const hash = createHash('sha256')
      .update(fs.readFileSync(skill))
      .digest('hex');
    // O `computedHash` do lock foi escrito por outra ferramenta e não bate com
    // sha256 do SKILL.md. Registamos o nosso para haver um valor reproduzível,
    // sem tratar a divergência como erro.
    const nota = renomeada ? ' (name alinhado à pasta)' : '';
    console.log(`ok       ${nome.padEnd(28)} sha256=${hash.slice(0, 16)}${nota}`);
  } catch (erro) {
    falhas += 1;
    console.error(`FALHOU   ${nome.padEnd(28)} ${erro.message.split('\n')[0]}`);
  } finally {
    fs.rmSync(temporario, { recursive: true, force: true });
  }
}

console.log(`\n${escolhidas.length - falhas}/${escolhidas.length} instaladas em .claude/skills/`);
process.exit(falhas > 0 ? 1 : 0);
