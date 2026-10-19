const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..', 'outlook-screensaver');
const directory = path.join(root, 'components');

// Desktop interpreters do not enforce Roku's native-component thread restrictions.
// Catch forbidden component creation in render scripts and Task initialization.
const forbidden = /CreateObject\s*\(\s*"(roFontRegistry|roFont|roUrlTransfer|roMessagePort|roFileSystem|roRegistrySection|roScreen|roCompositor)"/i;
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
const manifest = fs.readFileSync(path.join(root, '..', 'dashboard-app', 'manifest'), 'utf8');
assert(/^title=Sleep Dashboard$/m.test(manifest), 'App must have a normal Roku Home tile');
assert(!/^screensaver_title=/m.test(manifest), 'Interactive app must not advertise a screensaver entry point');
const entry = fs.readFileSync(path.join(root, '..', 'dashboard-app', 'source', 'main.brs'), 'utf8');
assert(/sub Main\(/i.test(entry) && !/RunScreenSaver/i.test(entry), 'Interactive package uses Main, not RunScreenSaver');
const calendar = fs.readFileSync(path.join(directory, 'CalendarTask.xml'), 'utf8');
assert(/<field\b(?=[^>]*\bid="agenda")(?=[^>]*\balwaysNotify="true")[^>]*\/>/i.test(calendar),
  'Repeated calendar text must still notify the scene after a range/filter change');
const pulse = fs.readFileSync(path.join(directory, 'AppKeepRunning.brs'), 'utf8');
assert(/m\.top\.insertChild\(m\.appKeepVideo, 0\)/.test(pulse), 'Media must stay below the opaque black background');
assert(/m\.appKeepVideo\.loop = false/.test(pulse), 'Hourly experiment must never loop continuously');
assert(/m\.appKeepVideo\.enableUI = false/.test(pulse) && /m\.appKeepVideo\.mute = true/.test(pulse),
  'Playback must not display player controls or produce sound');
assert(!/appWake\(|appShowPage\(|appPauseForInput\(|appIdleClock\.Mark\(|setFocus\(/i.test(pulse),
  'Media pulses cannot wake, navigate, focus a player, or impersonate remote activity');
assert(!/https?:\/\//.test(pulse), 'Keep-running experiment must have no network stream fallback');
assert(!/UpdateLastKeypressTime|:8060|keypress\//i.test(pulse + entry), 'No simulated keypress keep-alive');
assert(!/<Video\b/i.test(fs.readFileSync(path.join(directory, 'NightScheduleScene.xml'), 'utf8')),
  'Standalone screensaver must not instantiate a media player');
console.log('PASS: Hourly media pulse stays local, bounded, opt-in and separate from user activity.');
