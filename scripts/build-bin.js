import { readFileSync, writeFileSync, chmodSync } from 'fs';

const result = await Bun.build({
  entrypoints: ['./src/DinitGraph.mjs'],
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

const src = './src/DinitGraph.mjs';
const dest = './dist/dinit-graph';

const content = readFileSync(src, 'utf8');
writeFileSync(dest, '#!/usr/bin/env bun\n' + content);
chmodSync(dest, 0o755);

console.log('✅ Binary ready: ./dist/dinit-graph');