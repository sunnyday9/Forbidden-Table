"""Exercise the bilingual design viewer, not Godot or controller routing."""
import json, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
code=r'''async page=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const base='http://127.0.0.1:8845/forbidden_table_spec/design/stage4_5/v2/';
 await page.goto(base+'gallery-zh_CN.html#workshop-target');await page.evaluate(()=>document.fonts.ready);
 await page.evaluate(()=>window.FT_SHOW('workshop-target'));
 await page.locator('#mode').selectOption('Fast');await page.locator('#reduced').check();await page.locator('#ambient').uncheck();await page.locator('#specimen').selectOption('deck');
 const snap=async()=>page.evaluate(()=>({locale:document.documentElement.lang,screen:window.FT_ACTIVE,mode:document.getElementById('mode').value,reduced:document.getElementById('reduced').checked,ambient:document.getElementById('ambient').checked,specimen:document.getElementById('specimen').value,tiles:[...document.querySelectorAll('#stage .tile')].map(t=>({face:t.dataset.face,state:t.dataset.state,label:t.getAttribute('aria-label')}))}));
 const chinese=await snap();await page.locator('#language').selectOption('en');await page.waitForURL('**/gallery.html?**');await page.evaluate(()=>document.fonts.ready);const english=await snap();
 await page.locator('#language').selectOption('zh_CN');await page.waitForURL('**/gallery-zh_CN.html?**');await page.evaluate(()=>document.fonts.ready);const roundtrip=await snap();
 await page.locator('#specimen').selectOption('baseline');await page.evaluate(()=>window.FT_SHOW('battle-table'));await page.locator('#stage .tile').first().click();
 const tileFeedback=await page.locator('#review-feedback').innerText();await page.locator('#stage .tile').first().focus();await page.keyboard.press('Tab');
 const focus=await page.evaluate(()=>({label:document.activeElement.getAttribute('aria-label'),outline:getComputedStyle(document.activeElement).outlineStyle,width:getComputedStyle(document.activeElement).outlineWidth}));
 const autonyms=await page.locator('#language').innerText();
 await page.goto(base+'language.html');await page.evaluate(()=>document.fonts.ready);const languages=[];
 for(const slug of ['language','language-zh']){
  await page.evaluate(slug=>window.FT_SHOW(slug),slug);await page.evaluate(()=>document.fonts.ready);
  const dimensions=await page.evaluate(()=>{const r=document.querySelector('#stage .screen'),b=r.getBoundingClientRect();return {width:b.width,height:b.height,footerBottom:r.lastElementChild.getBoundingClientRect().bottom-b.top,buttonOverflow:[...r.querySelectorAll('.action')].filter(b=>b.scrollWidth>b.clientWidth+1||b.scrollHeight>b.clientHeight+1).map(b=>b.textContent)};});
  const id=slug==='language'?'L1':'L2';await page.locator('#stage .screen').screenshot({path:__ROOT__+'/mockups/'+id+'-'+slug+'.png'});
  languages.push({slug,...dimensions,figma:await page.locator('#figma-frame').getAttribute('href'),static:await page.locator('#static-image').getAttribute('href')});
 }
 await page.goto(base+'gallery.html');await page.evaluate(()=>document.fonts.ready);const englishLayouts=[];
 for(const slug of ['character','battle-table','settings','workshop-target','save-error']){
  await page.evaluate(slug=>window.FT_SHOW(slug),slug);englishLayouts.push(await page.evaluate(()=>{const r=document.querySelector('#stage .screen');return {slug:window.FT_ACTIVE,width:r.clientWidth,height:r.clientHeight,buttonOverflow:[...r.querySelectorAll('.action')].filter(b=>b.scrollWidth>b.clientWidth+1||b.scrollHeight>b.clientHeight+1).map(b=>b.textContent)};}));
 }
 await page.goto(base+'gallery-zh_CN.html#battle-table');
 return {scope:'Browser design viewer only',chinese,english,roundtrip,tileFeedback,focus,autonyms,languages,englishLayouts,errors};
}'''.replace('__ROOT__',json.dumps(str(ROOT)))
r=subprocess.run(['bash',sys.argv[1],'-s='+sys.argv[2],'run-code',code],cwd='/tmp',text=True,capture_output=True)
if r.returncode:print(r.stdout+r.stderr);raise SystemExit(r.returncode)
j=json.loads(r.stdout.split('### Result\n',1)[1].split('\n### ',1)[0])
(ROOT/'source/interaction_checks.json').write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
for state in ['english','roundtrip']:
 for key in ['screen','mode','reduced','ambient','specimen']:assert j[state][key]==j['chinese'][key],key
 assert [(t['face'],t['state']) for t in j[state]['tiles']]==[(t['face'],t['state']) for t in j['chinese']['tiles']]
assert j['roundtrip']['locale']=='zh-CN' and j['english']['locale']=='en'
assert j['chinese']['tiles'][2]['label']=='二条，副本 2'
assert '一条' in j['tileFeedback'] and '查看牌' in j['tileFeedback']
assert j['focus']['width']=='3px' and j['focus']['outline']!='none'
assert all(not s['buttonOverflow'] and s['footerBottom']<=524 for s in j['languages'])
assert all(not s['buttonOverflow'] for s in j['englishLayouts']) and not j['errors']
print(json.dumps({'languageRoundTrip':True,'fixtureInstancesPreserved':True,'localizedTileLabels':True,'keyboardFocus':True,'languageSpecimens':2,'englishRegressionScreens':5,'errors':j['errors']}))
