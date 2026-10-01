"""Check the review package and its provenance, without running the game."""
import hashlib, json, re, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
screens=json.loads((ROOT/'source/screens.json').read_text())
ledger=json.loads((ROOT/'source/figma_ledger.json').read_text())
layout=json.loads((ROOT/'source/layout_checks.json').read_text())
native=json.loads((ROOT/'source/figma_checks.json').read_text())
motion=json.loads((ROOT/'source/motion_checks.json').read_text())
clip=json.loads((ROOT/'source/native_motion_checks.json').read_text())
faces=json.loads((ROOT/'assets/chinese-tiles/manifest.json').read_text())
native_faces=json.loads((ROOT/'source/chinese_face_checks.json').read_text())
assert len(faces['assets'])==34 and len({a['definitionId'] for a in faces['assets']})==34
assert not native_faces['failures'] and not native_faces['catalogCaptionOverflow']
assert native_faces['registryFaces']==34 and native_faces['tileInstances']==219
assert {a['file'] for a in faces['assets']}=={p.name for p in (ROOT/'assets/chinese-tiles').glob('*.png')}
for a in faces['assets']:
 assert hashlib.sha256((ROOT/'assets/chinese-tiles'/a['file']).read_bytes()).hexdigest()==a['sha256'],a['key']
assert next(a['file'] for a in faces['assets'] if a['key']=='HON:W')=='z7.png'
assert next(a['file'] for a in faces['assets'] if a['key']=='HON:WEST')=='z3.png'
assert len(screens)==len(ledger['frames'])==len(layout['screens'])==len(native['measurements'])==36
assert {s['slug'] for s in screens}=={s['slug'] for s in ledger['frames']}
assert len({s['id'] for s in ledger['frames']})==36
assert ledger['fileKey']=='xXzt7gEelGQh37Ak51ogGa'
assert all(s['width']==960 and s['height']==540 and not s['buttonOverflow'] and not s['horizontalPanelOverflow'] and s['footerBottom']<=524 for s in layout['screens'])
assert all(s['w']==960 and s['h']==540 and not s['buttonOverflow'] and not s['headerOverflow'] and s['minButtonHeight']>=44 for s in native['measurements'])
assert len(motion['results'])==12
assert all(s['receipt']=='Complete Hand settled. → Boss enters phase 2. → Victory!' for s in motion['results'])
assert clip['frames'][1]['time']>.15 and clip['frames'][2]['time']>.6
for s in screens:
 p=ROOT/'mockups'/f"{s['id']}-{s['slug']}.png"
 assert p.exists(),p
 assert struct.unpack('>II',p.read_bytes()[16:24])==(960,540),p
for name in ['character','battle-table','pattern-settlement','map-act-1','reward-normal','workshop-target','summary-victory']:
 p=ROOT/'mockups/figma'/f'{name}.png'
 assert struct.unpack('>II',p.read_bytes()[16:24])==(960,540),p
for i in range(1,4):
 assert (ROOT/f'mockups/figma/index-{i}.png').exists()
for md in ROOT.rglob('*.md'):
 for target in re.findall(r'\]\(([^)]+)\)',md.read_text()):
  if not re.match(r'^[a-z]+:',target) and not target.startswith('#'):
   assert (md.parent/target.split('#')[0]).exists(),(md,target)
for p in ROOT.rglob('*'):
 if p.is_file() and p.name!='check_package.py' and p.suffix in {'.json','.js','.html','.md','.css','.py'}:
  assert not re.search(r'X-Amz-(?:Signature|Credential)|uploadUrl|downloadUrl',p.read_text()),p
def luminance(c):
 rgb=[int(c[i:i+2],16)/255 for i in (1,3,5)]
 rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
 return sum(v*w for v,w in zip(rgb,[.2126,.7152,.0722]))
def contrast(a,b):
 x,y=sorted([luminance(a),luminance(b)])
 return round((y+.05)/(x+.05),2)
tokens=json.loads((ROOT/'source/tokens.json').read_text())
pairs=[('text','panel'),('muted','raised'),('ink','brass'),('focus','panel'),('error','paper')]
contrasts={f'{a}/{b}':contrast(tokens[a],tokens[b]) for a,b in pairs}
assert all(v>=4.5 for v in contrasts.values()),contrasts
files=[p for p in ROOT.rglob('*') if p.is_file() and p.name!='package_checks.json']
report={'scope':'Design artifacts only; approval pending','revision':'V2.1 Chinese tile faces','screens':36,'browserPngs':len(list((ROOT/'mockups').glob('*.png'))),'nativePngs':len(list((ROOT/'mockups/figma').glob('*.png'))),'motionPngs':len(list((ROOT/'motion').glob('*.png'))),'generatedArtAssets':2,'chineseTileAssets':34,'baselineSolidColorContrast':contrasts,'checks':{'layout':True,'nativeLayout':True,'motion':True,'nativePlayback':True,'chineseFaceMapping':True,'localMarkdownLinks':True,'noSignedUrls':True},'files':[{'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(files)]}
(ROOT/'source/package_checks.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='files'}))
