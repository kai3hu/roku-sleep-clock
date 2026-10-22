// Export the native settings renderer's mock node tree, not a separately laid-out UI.
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const brsPath = path.dirname(require.resolve('brs/package.json', { paths: [root, path.join(root, '.tools')] }));
const brs = require(brsPath);
const { Interpreter } = require(path.join(brsPath, 'lib/interpreter'));
const files = ['DisplaySchedule', 'SharedContent', 'TelegramContent', 'AppSettings', 'AppClock', 'AppMenu', 'AppKeepRunning', 'AppControls', 'NightScheduleScene']
  .map(name => path.join(root, 'outlook-screensaver/components', `${name}.brs`));
files.push(...['app-tests', 'keep-running-tests', 'clock-settings-tests', 'settings-preview'].map(name => path.join(root, 'tests', `${name}.brs`)));
const statements = brs.lexParseSync(files, { root });
new Interpreter().exec(statements, brs.types.BrsBoolean.True);
