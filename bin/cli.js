#!/usr/bin/env node
import('../build/cli/index.js').catch(err => {
  console.error('Failed to load CLI:', err.message);
  process.exit(1);
});
