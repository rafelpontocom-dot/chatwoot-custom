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
        contract.paths.some(
          prefix =>
            path === prefix || path.startsWith(`${prefix.replace(/\/$/, '')}/`)
        )
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
      },
    });
    const cwd = process.cwd();
    const registry = JSON.parse(
      readFileSync(resolve(cwd, 'config/raevo/upstream-contracts.json'), 'utf8')
    );
    const errors = validateContracts(registry, cwd);
    if (errors.length) throw new Error(errors.join('\n'));
    if (values['check-contracts']) {
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
