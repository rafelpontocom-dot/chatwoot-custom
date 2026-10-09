import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { afterEach, test } from 'node:test';
import {
  buildAuditReport,
  changedNativeFiles,
  checkNativeCoverage,
  validateContracts,
} from '../raevo-upstream-audit.mjs';

const directories = [];
afterEach(() =>
  directories
    .splice(0)
    .forEach(path => rmSync(path, { recursive: true, force: true }))
);

function fixture() {
  const cwd = mkdtempSync(join(tmpdir(), 'raevo-upstream-audit-'));
  directories.push(cwd);
  const git = (...args) =>
    execFileSync('git', args, {
      cwd,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  const write = (path, content) => {
    mkdirSync(dirname(join(cwd, path)), { recursive: true });
    writeFileSync(join(cwd, path), content);
  };
  const commit = name => {
    git('add', '.');
    git('commit', '-m', name);
  };
  git('init', '-b', 'base');
  git('config', 'user.name', 'Audit fixture');
  git('config', 'user.email', 'audit@raevo.test');
  write('native.vue', 'header\ncontent\nfooter\n');
  write('spec/native.spec.js', 'fixture');
  commit('base');
  const base = git('rev-parse', 'HEAD');
  git('checkout', '-b', 'raevo');
  write('native.vue', 'RAEVO header\ncontent\nfooter\n');
  write('raevo-only.vue', 'extension');
  write('db/migrate/20261003120000_custom_labels.rb', 'custom');
  commit('raevo');
  git('checkout', '-b', 'upstream', base);
  write('native.vue', 'header\ncontent\nupstream footer\n');
  write('upstream-only.vue', 'upstream');
  write('db/migrate/20261003120000_upstream_labels.rb', 'upstream');
  commit('upstream');
  return { cwd, base, write, git };
}

const contracts = {
  version: 1,
  contracts: [
    { id: 'navigation', paths: ['native.vue'], tests: ['spec/native.spec.js'] },
  ],
};

test('reports both-side changes even when the edits would merge without conflict', () => {
  const { cwd, base, git } = fixture();
  const report = buildAuditReport({
    cwd,
    raevoRef: 'raevo',
    upstreamRef: 'upstream',
    contracts,
  });
  assert.equal(report.baseSha, base);
  assert.equal(report.raevo.sha, git('rev-parse', 'raevo'));
  assert.equal(report.upstream.sha, git('rev-parse', 'upstream'));
  assert.deepEqual(report.overlaps, [
    {
      path: 'native.vue',
      contracts: ['navigation'],
      tests: ['spec/native.spec.js'],
    },
  ]);
  assert.ok(report.raevoOnly.includes('raevo-only.vue'));
  assert.ok(report.upstreamOnly.includes('upstream-only.vue'));
});

test('lists unregistered overlaps for manual review, rather than hiding them', () => {
  const { cwd } = fixture();
  const report = buildAuditReport({
    cwd,
    raevoRef: 'raevo',
    upstreamRef: 'upstream',
    contracts: { version: 1, contracts: [] },
  });
  assert.deepEqual(report.unregisteredOverlaps, ['native.vue']);
});

test('detects different migrations that share the same version', () => {
  const { cwd } = fixture();
  const report = buildAuditReport({
    cwd,
    raevoRef: 'raevo',
    upstreamRef: 'upstream',
    contracts,
  });
  assert.deepEqual(report.migrationVersionCollisions, [
    {
      version: '20261003120000',
      paths: [
        'db/migrate/20261003120000_custom_labels.rb',
        'db/migrate/20261003120000_upstream_labels.rb',
      ],
    },
  ]);
});

test('fails on an invalid ref instead of guessing the upstream base from a version string', () => {
  const { cwd } = fixture();
  assert.throws(
    () =>
      buildAuditReport({
        cwd,
        raevoRef: 'missing',
        upstreamRef: 'upstream',
        contracts,
      }),
    /missing|revision|unknown/i
  );
});

test('checks that every registered contract has existing test evidence', () => {
  const { cwd } = fixture();
  assert.deepEqual(validateContracts(contracts, cwd), []);
  const invalid = {
    version: 1,
    contracts: [
      {
        id: 'navigation',
        paths: ['native.vue'],
        tests: ['spec/missing.spec.js'],
      },
    ],
  };
  assert.match(
    validateContracts(invalid, cwd).join('\n'),
    /spec\/missing.spec.js/
  );
});

test('refuses shallow history instead of inventing an upstream base', () => {
  const { cwd, write, git } = fixture();
  write('.git/shallow', `${git('rev-parse', 'HEAD')}\n`);
  assert.throws(
    () =>
      buildAuditReport({
        cwd,
        raevoRef: 'raevo',
        upstreamRef: 'upstream',
        contracts,
      }),
    /Shallow history/
  );
});

test('rejects duplicate contract IDs and contracts with no paths or tests', () => {
  const { cwd } = fixture();
  const invalid = {
    version: 1,
    contracts: [
      { id: 'navigation', paths: [], tests: [] },
      contracts.contracts[0],
    ],
  };
  const errors = validateContracts(invalid, cwd).join('\n');
  assert.match(errors, /duplicate/i);
  assert.match(errors, /paths/i);
  assert.match(errors, /tests/i);
});

// A porta do inventário: o que um upgrade pode reescrever é o ficheiro do
// upstream que o Raevo alterou ou apagou — nunca o que o Raevo acrescentou.
test('lists the native files Raevo changed or deleted, not the ones it added', () => {
  const { cwd, base, git } = fixture();
  git('checkout', 'raevo');
  git('rm', '-q', 'spec/native.spec.js');
  git('commit', '-m', 'raevo drops a native spec');
  assert.deepEqual(changedNativeFiles(cwd, base, 'raevo'), [
    'native.vue',
    'spec/native.spec.js',
  ]);
});

test('counts native edits that are not committed yet', () => {
  const { cwd, base, git, write } = fixture();
  git('checkout', '-q', 'base');
  assert.deepEqual(changedNativeFiles(cwd, base), []);
  write('native.vue', 'edited before the commit\n');
  assert.deepEqual(changedNativeFiles(cwd, base), ['native.vue']);
});

const semDivida = { version: 1, files: {} };

test('fails a native file changed outside the inventory', () => {
  const { errors } = checkNativeCoverage({
    changed: ['native.vue', 'app/models/team.rb'],
    registry: contracts,
    debt: semDivida,
  });
  assert.equal(errors.length, 1);
  assert.match(errors[0], /^app\/models\/team\.rb: .*contract/);
});

test('accepts contracted, regenerated and declared-debt native files', () => {
  const report = checkNativeCoverage({
    changed: [
      'native.vue',
      'components/sidebar/Sidebar.vue',
      'pnpm-lock.yaml',
      'app/old.vue',
    ],
    registry: {
      ...contracts,
      regenerated: ['pnpm-lock.yaml'],
      contracts: [
        ...contracts.contracts,
        { id: 'sidebar', paths: ['components/sidebar/'], tests: ['x'] },
      ],
    },
    debt: { version: 1, files: { telas: ['app/old.vue'] } },
  });
  assert.deepEqual(report.errors, []);
  assert.deepEqual(report.counts, {
    changed: 4,
    contracted: 2,
    regenerated: 1,
    debt: 1,
  });
});

test('makes a paid or vanished debt entry leave the list', () => {
  const { errors } = checkNativeCoverage({
    changed: ['native.vue'],
    registry: contracts,
    debt: { version: 1, files: { telas: ['native.vue', 'app/gone.vue'] } },
  });
  assert.equal(errors.length, 2);
  assert.match(errors.join('\n'), /native\.vue: .*covered by a contract/);
  assert.match(errors.join('\n'), /app\/gone\.vue: .*no longer differs/);
});

test('lets the debt list shrink but never grow against the base branch', () => {
  const changed = ['app/old.vue', 'app/new.vue'];
  const baseDebt = { version: 1, files: { telas: ['app/old.vue'] } };
  const grown = checkNativeCoverage({
    changed,
    registry: contracts,
    debt: { version: 1, files: { telas: ['app/old.vue', 'app/new.vue'] } },
    baseDebt,
  });
  assert.equal(grown.errors.length, 1);
  assert.match(grown.errors[0], /^app\/new\.vue: .*only shrinks/);

  const shrunk = checkNativeCoverage({
    changed: ['app/old.vue'],
    registry: contracts,
    debt: { version: 1, files: { telas: ['app/old.vue'] } },
    baseDebt: { version: 1, files: { telas: ['app/old.vue', 'app/x.vue'] } },
  });
  assert.deepEqual(shrunk.errors, []);
});
