import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const git = (cwd, ...args) =>
  execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
  });
const paths = output => output.split('\0').filter(Boolean).sort();
const coveredBy = (path, prefix) =>
  path === prefix || path.startsWith(`${prefix.replace(/\/$/, '')}/`);
const isContracted = (registry, path) =>
  registry.contracts.some(contract =>
    contract.paths.some(prefix => coveredBy(path, prefix))
  );
const debtPaths = debt => Object.values(debt?.files ?? {}).flat();
const DEBT_FILE = 'config/raevo/upstream-debt.json';

export function validateContracts(registry, cwd) {
  const errors = [];
  const ids = new Set();
  if (registry.version !== 1 || !Array.isArray(registry.contracts)) {
    return ['Unsupported contract registry version or missing contracts array'];
  }
  registry.contracts.forEach(contract => {
    if (!contract.id || ids.has(contract.id))
      errors.push(`Missing or duplicate contract ID: ${contract.id}`);
    ids.add(contract.id);
    if (!contract.paths?.length)
      errors.push(`${contract.id}: paths are required`);
    if (!contract.tests?.length)
      errors.push(`${contract.id}: tests are required`);
    (contract.tests ?? []).forEach(path => {
      if (!existsSync(resolve(cwd, path)))
        errors.push(`${contract.id}: missing test ${path}`);
    });
  });
  return errors;
}

export function buildAuditReport({ cwd, raevoRef, upstreamRef, contracts }) {
  if (git(cwd, 'rev-parse', '--is-shallow-repository').trim() === 'true') {
    throw new Error(
      'Shallow history: fetch the full history and tags before determining the upstream base'
    );
  }
  const raevoSha = git(
    cwd,
    'rev-parse',
    '--verify',
    `${raevoRef}^{commit}`
  ).trim();
  const upstreamSha = git(
    cwd,
    'rev-parse',
    '--verify',
    `${upstreamRef}^{commit}`
  ).trim();
  const baseSha = git(cwd, 'merge-base', raevoSha, upstreamSha).trim();
  const changed = sha =>
    paths(git(cwd, 'diff', '--no-renames', '--name-only', '-z', baseSha, sha));
  const raevoPaths = changed(raevoSha);
  const upstreamPaths = changed(upstreamSha);
  const raevoSet = new Set(raevoPaths);
  const upstreamSet = new Set(upstreamPaths);
  const overlaps = raevoPaths
    .filter(path => upstreamSet.has(path))
    .map(path => {
      const matches = contracts.contracts.filter(contract =>
        contract.paths.some(prefix => coveredBy(path, prefix))
      );
      return {
        path,
        contracts: matches.map(contract => contract.id),
        tests: [...new Set(matches.flatMap(contract => contract.tests))].sort(),
      };
    });
  const migrations = new Map();
  [raevoSha, upstreamSha].forEach(sha => {
    paths(
      git(cwd, 'ls-tree', '-r', '--name-only', '-z', sha, '--', 'db/migrate')
    ).forEach(path => {
      const version = path.match(/\/([0-9]+)_[^/]+\.rb$/)?.[1];
      if (!version) return;
      if (!migrations.has(version)) migrations.set(version, new Set());
      migrations.get(version).add(path);
    });
  });
  return {
    baseSha,
    raevo: { ref: raevoRef, sha: raevoSha },
    upstream: { ref: upstreamRef, sha: upstreamSha },
    overlaps,
    unregisteredOverlaps: overlaps
      .filter(item => !item.contracts.length)
      .map(item => item.path),
    raevoOnly: raevoPaths.filter(path => !upstreamSet.has(path)),
    upstreamOnly: upstreamPaths.filter(path => !raevoSet.has(path)),
    migrationVersionCollisions: [...migrations]
      .filter(([, entries]) => entries.size > 1)
      .map(([version, entries]) => ({ version, paths: [...entries].sort() })),
  };
}

// Os ficheiros do upstream que o Raevo alterou ou apagou: são estes que um
// upgrade pode reescrever sem conflito. Os que o Raevo acrescentou não contam.
// Sem `ref`, compara com a árvore de trabalho — o que ainda não foi gravado
// também conta, senão correr a porta antes do commit dava uma falsa garantia.
export function changedNativeFiles(cwd, upstreamRef, ref) {
  return paths(
    git(
      cwd,
      'diff',
      '--no-renames',
      '--name-only',
      '-z',
      '--diff-filter=MD',
      upstreamRef,
      ...(ref ? [ref] : [])
    )
  );
}

// A porta: cada ficheiro nativo alterado tem contrato com teste, é regenerado
// por ferramenta, ou está declarado na dívida — e a dívida só encolhe.
export function checkNativeCoverage({ changed, registry, debt, baseDebt }) {
  const regenerated = new Set(registry.regenerated ?? []);
  const owed = debtPaths(debt);
  const owedSet = new Set(owed);
  const changedSet = new Set(changed);
  const errors = [];
  changed
    .filter(
      path =>
        !isContracted(registry, path) &&
        !regenerated.has(path) &&
        !owedSet.has(path)
    )
    .forEach(path =>
      errors.push(
        `${path}: native file changed outside the upgrade inventory — protect it with a contract and a behaviour test in config/raevo/upstream-contracts.json`
      )
    );
  owed
    .filter(path => isContracted(registry, path))
    .forEach(path =>
      errors.push(
        `${path}: now covered by a contract — remove it from ${DEBT_FILE}`
      )
    );
  owed
    .filter(path => !changedSet.has(path))
    .forEach(path =>
      errors.push(
        `${path}: no longer differs from upstream — remove it from ${DEBT_FILE}`
      )
    );
  if (baseDebt) {
    const before = new Set(debtPaths(baseDebt));
    owed
      .filter(path => !before.has(path))
      .forEach(path =>
        errors.push(
          `${path}: the debt list only shrinks — protect the file with a contract instead`
        )
      );
  }
  return {
    errors,
    counts: {
      changed: changed.length,
      contracted: changed.filter(path => isContracted(registry, path)).length,
      regenerated: changed.filter(path => regenerated.has(path)).length,
      debt: owed.length,
    },
  };
}

function readBaseDebt(cwd, ref) {
  git(cwd, 'rev-parse', '--verify', `${ref}^{commit}`);
  if (!git(cwd, 'ls-tree', '--name-only', ref, '--', DEBT_FILE).trim()) {
    process.stdout.write(
      `${DEBT_FILE} does not exist on ${ref} yet: nothing to compare the debt with\n`
    );
    return null;
  }
  return JSON.parse(git(cwd, 'show', `${ref}:${DEBT_FILE}`));
}

function runNativeCoverage(cwd, registry, debtBase) {
  const tag = registry.upstreamBase;
  if (!tag)
    throw new Error('upstream-contracts.json: upstreamBase is required');
  try {
    git(cwd, 'rev-parse', '--verify', '--quiet', `${tag}^{commit}`);
  } catch {
    throw new Error(
      `Upstream base ${tag} is not available. Fetch it first:\n  git fetch --no-tags --depth=1 https://github.com/chatwoot/chatwoot.git refs/tags/${tag}:refs/tags/${tag}`
    );
  }
  const { errors, counts } = checkNativeCoverage({
    changed: changedNativeFiles(cwd, tag),
    registry,
    debt: JSON.parse(readFileSync(resolve(cwd, DEBT_FILE), 'utf8')),
    baseDebt: debtBase ? readBaseDebt(cwd, debtBase) : null,
  });
  if (errors.length) throw new Error(errors.join('\n'));
  process.stdout.write(
    `${counts.changed} native files differ from ${tag}: ${counts.contracted} under contract, ${counts.regenerated} regenerated, ${counts.debt} in the debt list\n`
  );
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const { values } = parseArgs({
      options: {
        raevo: { type: 'string' },
        upstream: { type: 'string' },
        'check-contracts': { type: 'boolean' },
        'check-native-coverage': { type: 'boolean' },
        'debt-base': { type: 'string' },
      },
    });
    const cwd = process.cwd();
    const registry = JSON.parse(
      readFileSync(resolve(cwd, 'config/raevo/upstream-contracts.json'), 'utf8')
    );
    const errors = validateContracts(registry, cwd);
    if (errors.length) throw new Error(errors.join('\n'));
    if (values['check-native-coverage']) {
      runNativeCoverage(cwd, registry, values['debt-base']);
    } else if (values['check-contracts']) {
      process.stdout.write(
        `${registry.contracts.length} upstream contracts have existing regression tests\n`
      );
    } else {
      if (!values.raevo || !values.upstream)
        throw new Error(
          'Usage: node scripts/raevo-upstream-audit.mjs --raevo <ref> --upstream <tag>'
        );
      process.stdout.write(
        JSON.stringify(
          buildAuditReport({
            cwd,
            raevoRef: values.raevo,
            upstreamRef: values.upstream,
            contracts: registry,
          }),
          null,
          2
        ) + '\n'
      );
    }
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
