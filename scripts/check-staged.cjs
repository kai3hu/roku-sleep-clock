const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const git = (...args) => execFileSync('git', args, { cwd: root, maxBuffer: 32 * 1024 * 1024 });
const files = git('diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z').toString('utf8').split('\0').filter(Boolean);
const configPath = path.join(root, 'outlook-screensaver/source/config.brs');
const config = fs.existsSync(configPath) ? fs.readFileSync(configPath, 'utf8') : '';
const privateUrl = config.match(/return\s+"(https?:\/\/[^"\r\n]+)"/)?.[1];
let errors = 0;
for (const file of files) {
  if (file === 'outlook-screensaver/source/config.brs' || /^(?:dist|\.tools|node_modules)\//.test(file)) {
    console.error(`Excluded file is staged: ${file}`);
    errors++;
    continue;
  }
  const content = git('show', `:${file}`);
  if (privateUrl && content.includes(Buffer.from(privateUrl))) {
    console.error(`Private calendar URL found in: ${file}`);
    errors++;
  }
  if (!content.includes(0) && /\p{Script=Han}/u.test(content.toString('utf8'))) {
    console.error(`Non-English text found in: ${file}`);
    errors++;
  }
}
if (errors) process.exit(1);
console.log(`Checked ${files.length} staged files: no Chinese text or private calendar URL.`);
