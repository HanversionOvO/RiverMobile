#!/usr/bin/env node

const { run } = require('../lib/create');

run(process.argv.slice(2)).catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`\n[create-river-miniapp] ${message}`);
  process.exit(1);
});
