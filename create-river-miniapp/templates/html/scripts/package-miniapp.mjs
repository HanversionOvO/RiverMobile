import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import archiver from 'archiver';

const root = process.cwd();
const configPath = path.join(root, 'miniapp.config.json');
const packageJsonPath = path.join(root, 'package.json');
const distDir = path.join(root, 'dist');

if (!fs.existsSync(configPath)) {
  throw new Error('Missing miniapp.config.json');
}
if (!fs.existsSync(distDir)) {
  throw new Error('Missing dist directory. Please run `npm run build` first.');
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf-8'));

const safeId = String(config.id).replace(/[^\w.-]+/g, '_');
const outputRoot = path.join(root, 'miniapp_output');
const packageDir = path.join(outputRoot, 'packages');
const zipName = `${safeId}.zip`;
const zipPath = path.join(packageDir, zipName);

fs.mkdirSync(packageDir, { recursive: true });

await new Promise((resolve, reject) => {
  const output = fs.createWriteStream(zipPath);
  const archive = archiver('zip', { zlib: { level: 9 } });
  output.on('close', resolve);
  output.on('error', reject);
  archive.on('error', reject);
  archive.pipe(output);
  archive.directory(distDir, false);
  archive.finalize();
});

const sha256 = crypto
  .createHash('sha256')
  .update(fs.readFileSync(zipPath))
  .digest('hex');

const slug = String(config.slug || safeId);
const iconPath = `./miniapps/${slug}/${config.icon}`;
const manifest = {
  version: '1.0.0',
  updated_at: new Date().toISOString(),
  apps: [
    {
      id: String(config.id),
      name: String(config.name),
      version: String(packageJson.version || '1.0.0'),
      url: `./miniapps/${slug}/${config.entry}`,
      icon: iconPath,
      package_url: `./packages/${zipName}`,
      package_sha256: sha256,
      description: String(config.description || ''),
      requires_auth: Boolean(config.requires_auth),
      enabled: Boolean(config.enabled ?? true),
      order: Number(config.order ?? 0),
      bridge_version: String(config.bridge_version || '1.0.0'),
      tags: Array.isArray(config.tags) ? config.tags : [],
    },
  ],
};

fs.mkdirSync(outputRoot, { recursive: true });
fs.writeFileSync(
  path.join(outputRoot, 'miniapps.partial.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
  'utf-8',
);

console.log(`Packed: ${zipPath}`);
console.log(`SHA256: ${sha256}`);
console.log('Manifest snippet: miniapp_output/miniapps.partial.json');
