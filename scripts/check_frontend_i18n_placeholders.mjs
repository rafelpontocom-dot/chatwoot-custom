import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const I18N_ROOT = 'app/javascript/dashboard/i18n/locale';
const nestedPlaceholderPattern = /\{\{[^{}]+\}\}/;

function listJsonFiles(dir) {
  return readdirSync(dir).flatMap(entry => {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) return listJsonFiles(path);
    return path.endsWith('.json') ? [path] : [];
  });
}

const failures = [];

for (const path of listJsonFiles(I18N_ROOT)) {
  const content = readFileSync(path, 'utf8');
  JSON.parse(content);

  content.split('\n').forEach((line, index) => {
    const match = line.match(nestedPlaceholderPattern);
    if (match) {
      failures.push(`${path}:${index + 1}: ${match[0]}`);
    }
  });
}

if (failures.length) {
  console.error(
    [
      'Frontend i18n JSON cannot contain {{...}} tokens.',
      'vue-i18n treats them as nested placeholders and can crash at runtime.',
      'Keep literal template tokens in component constants or backend config instead.',
      '',
      ...failures,
    ].join('\n')
  );
  process.exit(1);
}

console.log('Frontend i18n placeholder check passed.');
