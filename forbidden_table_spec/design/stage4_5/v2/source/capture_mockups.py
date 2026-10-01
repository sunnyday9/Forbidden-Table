"""Capture design fixtures using an already-open Playwright CLI session.

This measures the browser drawings only. It does not run or validate Godot.
Usage: python3 source/capture_mockups.py /path/to/playwright_cli.sh ft-design
Serve the repository and open gallery.html in that session first.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
capture_dir = ROOT / 'mockups'
capture_dir.mkdir(exist_ok=True)
code = r'''async (page) => {
 await page.reload();
 await page.locator('#specimen').selectOption('baseline');
 await page.evaluate(()=>document.fonts.ready);
 const screens=await page.evaluate(()=>window.FT_V2.screens.map(s=>({id:s.id,slug:s.slug})));
 const output=[],directory=__DIRECTORY__;
 for(const screen of screens){
  await page.evaluate(slug=>window.FT_SHOW(slug),screen.slug);
  await page.evaluate(()=>document.fonts.ready);
  const bounds=await page.evaluate(()=>{
   const root=document.querySelector('#stage .screen'),r=root.getBoundingClientRect();
   return {width:r.width,height:r.height,
    footerBottom:root.lastElementChild.getBoundingClientRect().bottom-r.top,
    buttonOverflow:[...root.querySelectorAll('.action')].filter(e=>e.scrollWidth>e.clientWidth+1||e.scrollHeight>e.clientHeight+1).map(e=>e.textContent),
    horizontalPanelOverflow:[...root.querySelectorAll('.panel')].filter(e=>e.scrollWidth>e.clientWidth+1).map(e=>e.getAttribute('aria-label')),
    scrollPanels:[...root.querySelectorAll('.panel')].filter(e=>e.scrollHeight>e.clientHeight+1).map(e=>e.getAttribute('aria-label'))};
  });
  const file=screen.id+'-'+screen.slug+'.png';
  await page.locator('#stage .screen').screenshot({path:directory+'/'+file});
  output.push({...screen,file,...bounds});
 }
 const stress=[];
 for(const specimen of ['expanded','large-text']){
  await page.locator('#specimen').selectOption(specimen);
  await page.evaluate(()=>window.FT_SHOW('pseudo-expansion'));
  const bounds=await page.evaluate(()=>{const root=document.querySelector('#stage .screen'),r=root.getBoundingClientRect();return {footerBottom:root.lastElementChild.getBoundingClientRect().bottom-r.top,buttonOverflow:[...root.querySelectorAll('.action')].filter(e=>e.scrollWidth>e.clientWidth+1||e.scrollHeight>e.clientHeight+1).map(e=>e.textContent)};});
  await page.locator('#stage .screen').screenshot({path:directory+'/stress-'+specimen+'.png'});
  stress.push({specimen,...bounds});
 }
 for(const specimen of ['wide','deck','desktop']){
  await page.locator('#specimen').selectOption(specimen);
  await page.evaluate(()=>window.FT_SHOW('battle-table'));
  await page.locator('#stage .viewport').screenshot({path:directory+'/window-'+specimen+'.png'});
 }
 await page.locator('#specimen').selectOption('baseline');
 await page.evaluate(()=>window.FT_SHOW('battle-table'));
 const modes=[];
 for(const mode of ['Normal','Fast','Instant']){
  await page.locator('#mode').selectOption(mode);
  modes.push({mode,text:await page.locator('#receipt-text').innerText()});
 }
 await page.locator('#mode').selectOption('Normal');
 await page.locator('#stage .action').first().focus();
 await page.keyboard.press('Tab');
 const keyboard=await page.evaluate(()=>({label:document.activeElement.getAttribute('aria-label'),outline:getComputedStyle(document.activeElement).outlineStyle,width:getComputedStyle(document.activeElement).outlineWidth}));
 return {renderer:'Playwright Chromium, browser design fixtures',screens:output,stress,modes,keyboard,
 fonts:await page.evaluate(()=>[...document.fonts].map(f=>({family:f.family,status:f.status})))};
}'''.replace('__DIRECTORY__', json.dumps(str(capture_dir)))

result = subprocess.run(['bash', sys.argv[1], '-s='+sys.argv[2], 'run-code', code],
                        cwd='/tmp', text=True, capture_output=True)
if result.returncode:
    print(result.stdout + result.stderr)
    raise SystemExit(result.returncode)
try:
    payload = result.stdout.split('### Result\n', 1)[1].split('\n### ', 1)[0]
    report = json.loads(payload)
except (IndexError, json.JSONDecodeError):
    print(result.stdout + result.stderr)
    raise
(ROOT / 'source/layout_checks.json').write_text(json.dumps(report, indent=2)+'\n')
failures = [s['slug'] for s in report['screens']
            if s['buttonOverflow'] or s['horizontalPanelOverflow'] or s['footerBottom']>524]
failures += [s['specimen'] for s in report['stress']
             if s['buttonOverflow'] or s['footerBottom']>524]
print(json.dumps({'screens':len(report['screens']), 'stress':len(report['stress']),
                  'failures':failures, 'report':'source/layout_checks.json'}))
if failures:
    raise SystemExit(1)
