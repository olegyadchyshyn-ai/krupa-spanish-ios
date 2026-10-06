// Аналіз структури JS-модулів: на якій глибині оголошено кожну функцію.
//
// Допомагає знайти помилку «функція є у файлі, але не видима в місці виклику»:
// така функція оголошена всередині іншої (глибина > 0), а не на верхньому рівні.
//
// Запуск:  node tools/check-js-scope.mjs [тека]

import { readdir, readFile } from 'node:fs/promises';
import { join, extname, relative } from 'node:path';

const root = process.argv[2] || 'web/js';

/** Грубо прибирає рядкові літерали, шаблони й коментарі. */
function stripLiterals(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\/\/[^\n]*/g, '')
    .replace(/`(?:\\[\s\S]|[^\\`])*`/g, '``')
    .replace(/'(?:\\.|[^'\\\n])*'/g, "''")
    .replace(/"(?:\\.|[^"\\\n])*"/g, '""');
}

async function collectFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await collectFiles(full));
    else if (extname(entry.name) === '.js' || extname(entry.name) === '.mjs') files.push(full);
  }
  return files;
}

const problems = [];
const unbalancedFiles = [];
const files = await collectFiles(root);

for (const file of files) {
  const source = await readFile(file, 'utf8');
  const lines = stripLiterals(source).split(/\r?\n/);

  let depth = 0;
  const declarations = [];

  lines.forEach((line, index) => {
    const trimmed = line.trim();
    const match = /^(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_$][\w$]*)/.exec(trimmed);
    if (match) declarations.push({ name: match[1], line: index + 1, depth });

    for (const character of line) {
      if (character === '{') depth += 1;
      else if (character === '}') depth -= 1;
    }
  });

  const unbalanced = depth !== 0;
  const nested = declarations.filter((item) => item.depth > 0);

  const label = relative(process.cwd(), file);
  if (unbalanced) unbalancedFiles.push(label);
  if (nested.length) {
    console.log(label + (unbalanced ? '  ⚠ незбалансовані дужки (кінцева глибина ' + depth + ')' : ''));
    for (const item of nested) {
      console.log('   • ' + item.name + ' — оголошена на глибині ' + item.depth + ' (рядок ' + item.line + ')');
      problems.push({ file: label, name: item.name, line: item.line });
    }
  }
}

console.log('');
console.log('Перевірено файлів: ' + files.length);
console.log('');
console.log('Довідково: вкладених оголошень ' + problems.length + ' — це нормально для JS,');
console.log('коли хелпери оголошують усередині функції екрана.');
if (unbalancedFiles.length) {
  console.log('');
  console.log('УВАГА: незбалансовані дужки у файлах: ' + unbalancedFiles.join(', '));
  process.exit(1);
}
console.log('Незбалансованих дужок немає.');
