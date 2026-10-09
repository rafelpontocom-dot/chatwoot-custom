import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { afterEach, test } from 'node:test';
import {
  buildAuditReport,
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
