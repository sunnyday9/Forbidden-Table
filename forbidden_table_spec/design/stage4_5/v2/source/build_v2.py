"""Art-led review fixtures only; reuse v1 semantics, never load Godot."""
from pathlib import Path
import json,copy
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT.parent
screens=copy.deepcopy(json.loads((BASE/'source/screens.json').read_text()))
tokens=dict(table='#0E1916',panel='#112820',raised='#243B30',text='#FFF1D5',muted='#D3D4B9',brass='#E7B65A',focus='#97EEDF',error='#FFB09B',success='#ADE1BC',edge='#9E865A',ink='#192218',paper='#292218',vermilion='#A84431')
def walk(d):
 yield d
 for c in d.get('children',[]):yield from walk(c)
for s in screens:
 s['version']='Proposed v2';s['notes']+=' V2 artwork and effects are presentation proposals only.'
 root=s['tree'];root['art']='salon';root['name']='Haunted table composition'
 header,status,body,footer=root['children'];header['h']=60;header['name']='Title rail';status['h']=20;status['name']='Run rail';body['name']=body.get('name','Decision surface');footer['name']='Commit rail'
 header['children'][0]['children'][0]['text']='FORBIDDEN TABLE  /  '+('NEW RUN' if s['slug'] in ['character','contract'] else 'THE HAUNTED TABLE')
 title=header['children'][0]['children'][1];title['size']=32
 if s['slug']=='character':title['text']='Take your seat'
 if s['slug']=='contract':title['text']='Sign your Contract'
 if s['slug']=='battle-table':title['text']='Your turn at the table'
 if s['slug']=='summary-victory':title['text']='Victory · Your Build Story'
 if s['slug']=='pseudo-expansion':title['text']='Recovery · Expanded text'
 s['title']=title['text']
 for d in walk(root):
  if d['type']=='panel':d['surface']='lacquer'
 if s['slug']=='character':
  for i,c in enumerate(body['children']):
   c['surface']='portrait';c['portrait']=i;c['gap']=4
   title,emblem,desc,inspect,state=c['children'];title['size']=24;title['serif']=True
   desc['size']=14;desc['w']=272
   if i==2:desc['text']='Locked in this profile.\nUnlock: Act 2 Normal Ending.'
   else:desc['text']=desc['text'].replace('Relic: ','').replace('Core: ','')
   c['children']=[dict(type='col',w=272,h=138,children=[]),title,desc,inspect,state]
  s['notes']+=' Portrait appearances are new cosmetic concepts, not lore or final approved Character art.'
 if s['slug'] in ['contract','event','event-unavailable','help','save-error','pseudo-expansion']:
  for d in walk(body):
   if d['type']=='panel':d['surface']='paper'
 if s['slug'] in ['battle-table','battle-empty','pattern-settlement','tutorial','complete-hand','critical-feedback','workshop-target']:
  body['children'][0]['surface']='table'
  if body['children'][0]['name']=='Battle table':
   left=body['children'][0];left['children'][0]['surface']='enemy';left['children'][0]['name']='Enemy intent banner'
   left['children'][0]['h']=60;left['children'][1]['h']=20;left['children'][2]['h']=134;left['children'][3]['h']=64
   left['children'][2]['name']='Hand tray';left['children'][3]['name']='Zone wells'
   left['children']=[left['children'][0],left['children'][1],left['children'][3],left['children'][2]]
 if s['slug'].startswith('reward-'):
  for i,c in enumerate(body['children']):
   c['surface']='reward';c['sigil']=i;emblem=c['children'][1]
   if emblem['type']=='row':
    emblem['name']='Reward emblem';emblem['h']=128;emblem['align']='center'
    for t in emblem['children']:t['w']=63;t['h']=96;t['large']=True
   else:
    c['children'][1]=dict(type='sigil',w=272,h=128,index=i,kind='RULE BREAKER' if s['slug']=='reward-boss' else 'RELIC')
 if s['slug']=='shop':body['children'][0]['surface']='shop'
 if s['slug'].startswith('workshop-'):
  for d in walk(body):
   if d['type']=='panel' and d.get('surface')!='table':d['surface']='workshop'
 if s['slug'].startswith('summary-') or s['slug'] in ['act-transition','run-complete']:
  body['children'][0]['surface']='chronicle'
  if s['slug']=='summary-victory':body['children'][0]['sigil']=0
root_data={'version':'Proposed v2','screens':screens,'tokens':tokens}
ledger=ROOT/'source/figma_ledger.json'
if ledger.exists():root_data['ledger']=json.loads(ledger.read_text())
(ROOT/'source/screens.json').write_text(json.dumps(screens,ensure_ascii=False,indent=2)+'\n')
(ROOT/'source/tokens.json').write_text(json.dumps(tokens,indent=2)+'\n')
(ROOT/'source/review_data.js').write_text('window.FT_V2='+json.dumps(root_data,ensure_ascii=False)+';\n')
(ROOT/'screen_manifest.json').write_text(json.dumps([{k:s[k] for k in ['id','slug','title','states','notes','width','height']} for s in screens],ensure_ascii=False,indent=2)+'\n')
print('36 V2 fixtures; game semantics carried from v1')
