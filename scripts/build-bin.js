import { readFileSync, writeFileSync, chmodSync } from 'fs';

const result = await Bun.build({
  entrypoints: ['./src/DinitDependencyGraph.mjs'],
  outdir: './dist',
  naming: '[name]',
  target: 'bun',
  bundle: true,
  minify: true,
});

if (!result.success) {
  console.error(result.logs);
  process.exit(1);
}

const src = './src/DinitDependencyGraph.mjs';
const dest = './dist/dinit-dependency-graph';

const content = readFileSync(src, 'utf8');
writeFileSync(dest, '#!/usr/bin/env bun\n' + content);
chmodSync(dest, 0o755);

console.log('✅ Binary ready: ./dist/dinit-dependency-graph');