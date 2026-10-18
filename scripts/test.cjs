const path = require('node:path');
const { spawnSync } = require('node:child_process');
require('./check-scene-threads.cjs');

const root = path.resolve(__dirname, '..');
const cli = require.resolve('brs/bin/cli.js', { paths: [root, path.join(root, '.tools')] });
const suites = [
  {
    files: [
      'outlook-screensaver/components/DisplaySchedule.brs',
      'outlook-screensaver/components/CalendarParser.brs',
      'outlook-screensaver/components/WeatherTask.brs',
      'tests/logic-tests.brs'
    ],
    success: /TEST_FAILURES=\s*0/
  },
  {
    files: [
      'outlook-screensaver/components/DisplaySchedule.brs',
      'outlook-screensaver/components/WikiContent.brs',
      'outlook-screensaver/components/TelegramContent.brs',
      'outlook-screensaver/components/NightScheduleScene.brs',
      'tests/display-tests.brs'
    ],
    success: /PASS: Text, chart and icon brightness transitions without hiding content/
  },
  {
    files: [
      'outlook-screensaver/components/DisplaySchedule.brs',
      'outlook-screensaver/components/WikiContent.brs',
      'outlook-screensaver/components/TelegramContent.brs',
      'outlook-screensaver/components/NightScheduleScene.brs',
      'tests/wiki-tests.brs'
    ],
    success: /WIKI_TEST_FAILURES=\s*0/
  },
  {
    files: [
      'outlook-screensaver/components/WikiContent.brs',
      'outlook-screensaver/components/TelegramContent.brs',
      'tests/telegram-tests.brs'
    ],
    success: /TELEGRAM_TEST_FAILURES=\s*0/
  }
];

for (const suite of suites) {
  const result = spawnSync(process.execPath, [cli, ...suite.files], {
    cwd: root,
    encoding: 'utf8',
    timeout: 60000
  });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error || result.status !== 0 || !suite.success.test(result.stdout || '') || /FAIL:/.test(result.stdout || '')) {
    process.exit(1);
  }
}
