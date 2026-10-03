"""Sample actual playback; SimpleHTTPServer does not support reliable MP4 seeking."""
import json, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
code = r'''async page=>{
 await page.goto('http://127.0.0.1:8845/forbidden_table_spec/design/stage4_5/v2/motion/video-review.html');
 await page.evaluate(()=>{const v=document.querySelector('video');v.controls=false;v.load();});
 await page.waitForFunction(()=>document.querySelector('video').readyState>=2);
 const frames=[];
 for(const [name,advance] of [['native-start',0],['native-mid',200],['native-settled',450],['native-held',600]]){
  if(advance){await page.evaluate(()=>document.querySelector('video').play());await page.waitForTimeout(advance);await page.evaluate(()=>document.querySelector('video').pause());}
  const metadata=await page.evaluate(()=>{const v=document.querySelector('video');const c=document.createElement('canvas');c.width=v.videoWidth;c.height=v.videoHeight;const ctx=c.getContext('2d');ctx.drawImage(v,0,0);const pixels=ctx.getImageData(580,200,100,200).data;let hash=0;for(const b of pixels)hash=(Math.imul(hash,31)+b)|0;return {time:v.currentTime,duration:v.duration,w:v.videoWidth,h:v.videoHeight,regionHash:hash};});
  await page.locator('video').screenshot({path:__ROOT__+'/motion/'+name+'.png'});
  frames.push({name,...metadata});
 }
 return {scope:'Native Figma export played in Chromium; cosmetic study only',frames};
}'''.replace('__ROOT__',json.dumps(str(ROOT)))
r=subprocess.run(['bash',sys.argv[1],'-s='+sys.argv[2],'run-code',code],cwd='/tmp',text=True,capture_output=True)
if r.returncode:print(r.stdout+r.stderr);raise SystemExit(r.returncode)
payload=json.loads(r.stdout.split('### Result\n',1)[1].split('\n### ',1)[0])
assert payload['frames'][1]['time'] > 0.15
assert payload['frames'][2]['time'] > 0.6
assert len({f['regionHash'] for f in payload['frames']}) >= 3
(ROOT/'source/native_motion_checks.json').write_text(json.dumps(payload,indent=2)+'\n')
print(json.dumps(payload))
