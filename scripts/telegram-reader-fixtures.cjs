// Optional public integration fixtures. All downloaded content stays in .tools.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const directory = path.join(root, '.tools');

async function get(url) {
  const response = await fetch(url, { signal: AbortSignal.timeout(20000) });
  if (!response.ok) throw new Error(`Public download failed: ${response.status}`);
  return response.text();
}

(async () => {
  const html = await get('https://t.me/s/DNSPODT');
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, 'telegram-feed.html'), html);
  const urls = [...new Set([...html.matchAll(/href="(https:\/\/telegra\.ph\/[^"?#]+)[^"]*"/gi)].map(match => match[1]))];
  const articles = {};
  for (const url of urls) {
    const parsed = new URL(url);
    const slug = decodeURIComponent(parsed.pathname.slice(1));
    if (!slug || /[\\/\x00-\x1f]/.test(slug) || slug.includes('..')) continue;
    const canonical = `https://telegra.ph/${encodeURIComponent(slug)}`;
    try {
      articles[canonical] = JSON.parse(await get(`https://api.telegra.ph/getPage/${encodeURIComponent(slug)}?return_content=true`));
    } catch (error) {
      console.warn(`Skipped unavailable public article: ${error.message}`);
    }
  }
  fs.writeFileSync(path.join(directory, 'telegram-articles.json'), JSON.stringify(articles));
  const cli = require.resolve('brs/bin/cli.js', { paths: [root, directory] });
  const result = spawnSync(process.execPath, [cli,
    'outlook-screensaver/components/SharedContent.brs',
    'outlook-screensaver/components/TelegramContent.brs',
    'tests/telegram-reader-live-tests.brs'
  ], { cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 8 * 1024 * 1024 });
  const exportLine = result.stdout?.split(/\r?\n/).find(line => line.startsWith('READER_PAGES_JSON='));
  if (result.error || result.status !== 0 || !exportLine || /FAIL:/.test(result.stdout || '')) {
    process.stderr.write(result.stderr || '');
    process.stdout.write((result.stdout || '').split(/\r?\n/).filter(line => !line.startsWith('READER_PAGES_JSON=')).join('\n'));
    throw new Error('Live article parsing or pagination failed');
  }
  const pages = JSON.parse(exportLine.slice('READER_PAGES_JSON='.length));
  fs.writeFileSync(path.join(directory, 'telegram-reader-pages.json'), JSON.stringify(pages));
  for (const page of pages) {
    const card = page[0];
    console.log(`Post ${card.post.id}: ${card.post.isArticle ? 'article' : 'message'}, page ${card.part}/${card.parts}, ${card.lines} lines, ${card.duration}s`);
  }
  console.log('PASS: Public source articles and single-message reader pages verified.');
})().catch(error => { console.error(error.message); process.exitCode = 1; });
