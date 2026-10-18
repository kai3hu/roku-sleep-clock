const path = require('node:path');
const { spawnSync } = require('node:child_process');

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
      'outlook-screensaver/components/NightScheduleScene.brs',
      'tests/display-tests.brs'
    ],
    success: /PASS: Startup, morning and midnight visibility transitions/
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
