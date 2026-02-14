import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const configPath = path.join(root, 'miniapp.config.json');
const distIndex = path.join(root, 'dist', 'index.html');

if (!fs.existsSync(configPath)) {
  console.error('Missing miniapp.config.json');
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const required = ['id', 'name', 'slug', 'entry', 'icon', 'bridge_version'];
for (const key of required) {
  const value = String(config[key] ?? '').trim();
  if (!value) {
    console.error(`miniapp.config.json missing field: ${key}`);
    process.exit(1);
  }
}

if (!fs.existsSync(distIndex)) {
  console.error('Missing dist/index.html. Please run `npm run build` first.');
  process.exit(1);
}

console.log('Mini-app check passed.');
