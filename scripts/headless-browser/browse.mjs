#!/usr/bin/env node
// Minimal headless-browser CLI built on Playwright.
//
//   node browse.mjs <url> [options]
//
// Options:
//   --screenshot <file>   save a PNG (default: screenshot.png)
//   --full                full-page screenshot
//   --text                print the rendered visible text
//   --html                print the rendered HTML
//   --links               print "text -> href" for all links
//   --pdf <file>          save a PDF
//   --strict-tls          do NOT ignore TLS errors (default: ignore, because the
//                         sandbox egress proxy MITMs TLS with an untrusted CA)
//   --wait <ms>           extra wait after load (default 0)
//   --timeout <ms>        navigation timeout (default 30000)
//
// Exit code is non-zero on navigation/launch failure.
import { chromium } from 'playwright';

const argv = process.argv.slice(2);
if (argv.length === 0 || argv[0] === '-h' || argv[0] === '--help') {
  console.log('usage: node browse.mjs <url> [--screenshot f.png] [--full] [--text] [--html] [--links] [--pdf f.pdf] [--wait ms] [--timeout ms]');
  process.exit(argv.length === 0 ? 2 : 0);
}

const url = argv[0];
const opt = (name, def = undefined) => {
  const i = argv.indexOf(name);
  return i === -1 ? def : argv[i + 1];
};
const flag = (name) => argv.includes(name);

const screenshot = opt('--screenshot');
const pdf = opt('--pdf');
const waitMs = Number(opt('--wait', '0'));
const timeout = Number(opt('--timeout', '30000'));
const strictTls = flag('--strict-tls');

const browser = await chromium.launch({
  args: strictTls ? [] : ['--ignore-certificate-errors'],
});
try {
  const page = await browser.newPage({
    viewport: { width: 1280, height: 800 },
    ignoreHTTPSErrors: !strictTls,
  });
  const resp = await page.goto(url, { waitUntil: 'domcontentloaded', timeout });
  if (waitMs) await page.waitForTimeout(waitMs);

  console.log(`status: ${resp ? resp.status() : 'n/a'}`);
  console.log(`url: ${page.url()}`);
  console.log(`title: ${await page.title()}`);

  if (flag('--text')) console.log('\n--- text ---\n' + (await page.innerText('body')));
  if (flag('--html')) console.log('\n--- html ---\n' + (await page.content()));
  if (flag('--links')) {
    const links = await page.$$eval('a[href]', (as) =>
      as.map((a) => `${a.innerText.trim().slice(0, 60)} -> ${a.href}`));
    console.log('\n--- links ---\n' + links.join('\n'));
  }
  if (screenshot || !pdf) {
    const out = screenshot || 'screenshot.png';
    await page.screenshot({ path: out, fullPage: flag('--full') });
    console.log(`screenshot: ${out}`);
  }
  if (pdf) {
    await page.pdf({ path: pdf });
    console.log(`pdf: ${pdf}`);
  }
} finally {
  await browser.close();
}
