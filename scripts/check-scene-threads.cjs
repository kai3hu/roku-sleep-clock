const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..', 'outlook-screensaver');
const directory = path.join(root, 'components');

// Desktop interpreters do not enforce Roku's native-component thread restrictions.
// Catch forbidden component creation in render scripts and Task initialization.
const forbidden = /CreateObject\s*\(\s*"(roFontRegistry|roFont|roUrlTransfer|roMessagePort|roFileSystem|roScreen|roCompositor)"/i;
for (const file of fs.readdirSync(directory).filter(file => file.endsWith('.xml'))) {
  const xml = fs.readFileSync(path.join(directory, file), 'utf8');
  const task = /extends="Task"/i.test(xml);
  for (const match of xml.matchAll(/<script[^>]+uri="pkg:\/([^"]+)"/gi)) {
    const scriptPath = path.join(root, match[1]);
    if (match[1] === 'source/config.brs' && !fs.existsSync(scriptPath)) continue;
    const source = fs.readFileSync(scriptPath, 'utf8');
    const checked = task ? (source.match(/sub\s+init\s*\([^)]*\)([\s\S]*?)end\s+sub/i)?.[1] || '') : source;
    assert(!forbidden.test(checked), `Forbidden native component on RENDER: ${match[1]}`);
  }
}
const scene = fs.readFileSync(path.join(directory, 'NightScheduleScene.brs'), 'utf8');
assert(!/telegramBuildPages\s*\(/i.test(scene), 'Pagination must run on TASK, not RENDER');
const task = fs.readFileSync(path.join(directory, 'TelegramTask.brs'), 'utf8');
assert(/pages\s*=\s*telegramBuildPages\s*\(/i.test(task), 'Telegram task must prepare pages before publishing data');
console.log('PASS: Render startup contains no forbidden native components or Telegram pagination.');
