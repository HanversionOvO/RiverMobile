const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline/promises');
const { stdin, stdout } = require('node:process');

const TEMPLATE_NAMES = ['html', 'vue', 'react'];
const TEXT_EXTENSIONS = new Set([
  '.json',
  '.js',
  '.mjs',
  '.ts',
  '.tsx',
  '.vue',
  '.html',
  '.css',
  '.md',
  '.txt',
  '.yml',
  '.yaml',
]);

function printHelp() {
  console.log(`
create-river-miniapp

Usage:
  create-river-miniapp [target-dir] [options]

Options:
  -t, --template <html|vue|react>  Template type
  --id <miniapp-id>                Mini-app id (default: local.<project_name>)
  --name <display-name>            Mini-app display name
  -y, --yes                        Skip all prompts
  -h, --help                       Show help
`);
}

function parseArgs(args) {
  const parsed = {
    targetDir: '',
    template: '',
    appId: '',
    appName: '',
    yes: false,
    help: false,
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === '-h' || arg === '--help') {
      parsed.help = true;
      continue;
    }
    if (arg === '-y' || arg === '--yes') {
      parsed.yes = true;
      continue;
    }
    if (arg === '-t' || arg === '--template') {
      parsed.template = (args[i + 1] || '').trim();
      i += 1;
      continue;
    }
    if (arg === '--id') {
      parsed.appId = (args[i + 1] || '').trim();
      i += 1;
      continue;
    }
    if (arg === '--name') {
      parsed.appName = (args[i + 1] || '').trim();
      i += 1;
      continue;
    }
    if (!arg.startsWith('-') && !parsed.targetDir) {
      parsed.targetDir = arg.trim();
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }
  return parsed;
}

function sanitizeName(value) {
  return value
    .trim()
    .replace(/[^\w.-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase();
}

function defaultAppId(projectName) {
  const safe = projectName.replace(/[^\w.-]+/g, '_');
  return `local.${safe || 'miniapp'}`;
}

async function askQuestion(rl, question, fallback = '') {
  const answer = await rl.question(question);
  const text = answer.trim();
  if (text) {
    return text;
  }
  return fallback;
}

async function askTemplate(rl, fallback) {
  console.log('\n请选择模板:');
  TEMPLATE_NAMES.forEach((name, index) => {
    console.log(`  ${index + 1}. ${name}`);
  });
  const raw = await askQuestion(rl, `模板 [${fallback}]: `, fallback);
  const lowered = raw.toLowerCase();
  if (TEMPLATE_NAMES.includes(lowered)) {
    return lowered;
  }
  const index = Number.parseInt(raw, 10);
  if (!Number.isNaN(index) && index >= 1 && index <= TEMPLATE_NAMES.length) {
    return TEMPLATE_NAMES[index - 1];
  }
  throw new Error(`Unsupported template: ${raw}`);
}

function ensureDirEmpty(targetDir) {
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
    return;
  }
  const files = fs.readdirSync(targetDir);
  if (files.length > 0) {
    throw new Error(`Target directory is not empty: ${targetDir}`);
  }
}

function copyDir(src, dst) {
  const entries = fs.readdirSync(src, { withFileTypes: true });
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const outName = entry.name === '_gitignore' ? '.gitignore' : entry.name;
    const dstPath = path.join(dst, outName);
    if (entry.isDirectory()) {
      copyDir(srcPath, dstPath);
      continue;
    }
    fs.copyFileSync(srcPath, dstPath);
  }
}

function applyTemplateVariables(targetDir, variables) {
  const walk = (dir) => {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const filePath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(filePath);
        continue;
      }
      const ext = path.extname(entry.name).toLowerCase();
      if (!TEXT_EXTENSIONS.has(ext)) {
        continue;
      }
      let text = fs.readFileSync(filePath, 'utf-8');
      Object.entries(variables).forEach(([key, value]) => {
        text = text.replaceAll(`{{${key}}}`, value);
      });
      fs.writeFileSync(filePath, text, 'utf-8');
    }
  };
  walk(targetDir);
}

async function run(rawArgs) {
  const args = parseArgs(rawArgs);
  if (args.help) {
    printHelp();
    return;
  }

  const cwd = process.cwd();
  const rl = readline.createInterface({ input: stdin, output: stdout });
  try {
    let targetName = args.targetDir.trim();
    if (!targetName && args.yes) {
      throw new Error('Target directory is required in --yes mode.');
    }
    if (!targetName) {
      targetName = await askQuestion(rl, '项目目录名: ');
    }
    if (!targetName) {
      throw new Error('Project directory name is required.');
    }

    const normalizedTarget = targetName.replace(/[\\/]+/g, path.sep);
    const projectDir = path.resolve(cwd, normalizedTarget);
    const projectName = sanitizeName(path.basename(projectDir));
    if (!projectName) {
      throw new Error(`Invalid project name: ${targetName}`);
    }

    let template = args.template.trim().toLowerCase();
    if (template && !TEMPLATE_NAMES.includes(template)) {
      throw new Error(`Unsupported template: ${template}`);
    }
    if (!template && args.yes) {
      template = 'html';
    }
    if (!template) {
      template = await askTemplate(rl, 'html');
    }

    let appId = args.appId.trim();
    if (!appId && args.yes) {
      appId = defaultAppId(projectName);
    }
    if (!appId) {
      appId = await askQuestion(rl, `小程序 ID [${defaultAppId(projectName)}]: `, defaultAppId(projectName));
    }
    if (!appId) {
      throw new Error('Mini-app id is required.');
    }

    let appName = args.appName.trim();
    const defaultName = projectName;
    if (!appName && args.yes) {
      appName = defaultName;
    }
    if (!appName) {
      appName = await askQuestion(rl, `小程序名称 [${defaultName}]: `, defaultName);
    }
    if (!appName) {
      throw new Error('Mini-app display name is required.');
    }

    ensureDirEmpty(projectDir);

    const templateDir = path.resolve(__dirname, '..', 'templates', template);
    if (!fs.existsSync(templateDir)) {
      throw new Error(`Template directory not found: ${templateDir}`);
    }
    copyDir(templateDir, projectDir);

    applyTemplateVariables(projectDir, {
      PROJECT_NAME: projectName,
      APP_ID: appId,
      APP_NAME: appName,
      TEMPLATE: template,
      YEAR: String(new Date().getFullYear()),
    });

    console.log(`\n项目已创建: ${projectDir}`);
    console.log('\n下一步:');
    console.log(`  cd ${path.relative(cwd, projectDir) || '.'}`);
    console.log('  npm install');
    console.log('  npm run dev');
    console.log('  npm run package:miniapp');
  } finally {
    rl.close();
  }
}

module.exports = { run };
