"""Verify review-viewer choreography and capture deterministic motion phases."""
import json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ZH=len(sys.argv)>3 and sys.argv[3]=='zh_CN'
if ZH: ROOT=ROOT/'bilingual'
(ROOT/'motion').mkdir(exist_ok=True)
code=r'''async page=>{
 await page.goto('http://127.0.0.1:8845/forbidden_table_spec/design/stage4_5/v2/__GALLERY__');
 await page.evaluate(()=>document.fonts.ready);await page.locator('#ambient').uncheck();
 const results=[];
 for(const mode of ['Normal','Fast','Instant']){
  await page.locator('#mode').selectOption(mode);
  for(const kind of ['draw','settlement','reward','workshop']){
   await page.locator('#motion').selectOption(kind);await page.evaluate(()=>window.FT_V2_DEMO());
   const data=await page.evaluate(()=>({animations:document.getAnimations().map(a=>({duration:a.effect.getTiming().duration,delay:a.effect.getTiming().delay,playState:a.playState})),receipt:document.getElementById('receipt-text').textContent,caption:document.getElementById('motion-caption').textContent,tiles:document.querySelectorAll('#stage .tile').length}));
   results.push({mode,kind,...data});
   await page.evaluate(()=>window.FT_V2_STOP());
  }
 }
 await page.locator('#mode').selectOption('Normal');await page.locator('#reduced').check();await page.locator('#motion').selectOption('draw');await page.evaluate(()=>window.FT_V2_DEMO());
 const reduced=await page.evaluate(()=>({durations:document.getAnimations().map(a=>a.effect.getTiming().duration),ambient:document.body.dataset.ambient}));
 await page.locator('#reduced').uncheck();await page.locator('#play').click();await page.waitForTimeout(60);await page.keyboard.press('Escape');
 const escape=await page.evaluate(()=>({animationCount:document.getAnimations().length,stampCount:document.querySelectorAll('.demo-stamp').length}));
 await page.locator('#motion').selectOption('settlement');await page.locator('#play').click();await page.waitForTimeout(50);await page.evaluate(()=>window.FT_SHOW('character'));await page.waitForTimeout(1300);
 const interrupt=await page.evaluate(()=>({active:window.FT_ACTIVE,stampCount:document.querySelectorAll('.demo-stamp').length,caption:document.getElementById('motion-caption').textContent}));
 await page.locator('#motion').selectOption('draw');await page.evaluate(()=>window.FT_V2_DEMO());
 for(const [name,time]of [['start',0],['mid',220],['settled',600]]){
  await page.evaluate(time=>{for(const a of document.getAnimations()){a.pause();a.currentTime=time;}},time);
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await page.locator('#stage .screen').screenshot({path:__ROOT__+'/motion/draw-'+name+'.png',animations:'allow'});
 }
 await page.evaluate(()=>window.FT_V2_STOP());
 return {scope:'Browser design viewer only; no Domain or Godot execution',results,reduced,escape,interrupt};
}'''.replace('__ROOT__',json.dumps(str(ROOT))).replace('__GALLERY__','gallery-zh_CN.html' if ZH else 'gallery.html')
r=subprocess.run(['bash',sys.argv[1],'-s='+sys.argv[2],'run-code',code],cwd='/tmp',text=True,capture_output=True)
if r.returncode:print(r.stdout+r.stderr);raise SystemExit(r.returncode)
payload=json.loads(r.stdout.split('### Result\n',1)[1].split('\n### ',1)[0]);(ROOT/'source/motion_checks.json').write_text(json.dumps(payload,indent=2)+'\n')
assert len(payload['results'])==12
expected='完整和牌已结算。→ 首领进入第二阶段。→ 胜利！' if ZH else 'Complete Hand settled. → Boss enters phase 2. → Victory!'
assert all(x['receipt']==expected for x in payload['results'])
assert payload['escape']['animationCount']==0 and payload['escape']['stampCount']==0
assert payload['interrupt']['active']=='character' and payload['interrupt']['stampCount']==0
assert payload['reduced']['ambient']=='false' and all(d==0 for d in payload['reduced']['durations'])
print(json.dumps({'motionCases':12,'receiptPreserved':True,'escapeStopped':True,'interruptionSafe':True,'reducedMotion':True}))
