"""Validate the bilingual design artifacts and font coverage, without Godot."""
import csv, hashlib, json, re, struct, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
V2=ROOT.parent
REPO=V2.parents[3]
def read(path):return json.loads(path.read_text())
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
english=read(V2/'source/screens.json');chinese=read(ROOT/'source/screens.zh_CN.json')
layout=read(ROOT/'source/layout_checks.json');native=read(ROOT/'source/figma_checks.json')
motion=read(ROOT/'source/motion_checks.json');interaction=read(ROOT/'source/interaction_checks.json')
coverage=read(ROOT/'source/coverage.json')
def structure(node):
 return {k:([structure(c) for c in v] if k=='children' else v) for k,v in node.items() if k not in ('text','kind','instanceLabel')}
assert len(english)==len(chinese)==len(layout['screens'])==36
for en,zh in zip(english,chinese):
 assert (en['id'],en['slug'],en['states'])==(zh['id'],zh['slug'],zh['states'])
 assert structure(en['tree'])==structure(zh['tree']),en['slug']
for screen in layout['screens']:
 assert not screen['buttonOverflow'] and not screen['horizontalPanelOverflow'] and screen['footerBottom']<=524,screen['slug']
 path=ROOT/'mockups'/f"{screen['id']}-{screen['slug']}.png"
 assert struct.unpack('>II',path.read_bytes()[16:24])==(960,540)
assert len(native['frames'])==38 and not native['failures']
assert len(motion['results'])==12 and all(r['receipt']=='完整和牌已结算。→ 首领进入第二阶段。→ 胜利！' for r in motion['results'])
assert motion['reduced']['ambient']=='false' and not motion['escape']['animationCount'] and not motion['interrupt']['stampCount']
assert not interaction['errors'] and interaction['chinese']['screen']=='workshop-target'
for key in ('screen','mode','reduced','ambient','specimen'):assert interaction['roundtrip'][key]==interaction['chinese'][key]
assert interaction['chinese']['tiles'][2]['label']=='二条，副本 2'
assert coverage['runtime_keys']==962 and coverage['runtime_translation_complete'] is False
assert digest(REPO/'localization/en.csv')==coverage['source_sha256']
inventory=list(csv.DictReader((ROOT/'source/runtime-key-inventory.csv').open()))
runtime=list(csv.DictReader((REPO/'localization/en.csv').open()))
assert {r['existing_key'] for r in inventory}=={r['keys'] for r in runtime}
assert len(inventory)==len(runtime)==962
def format12_ranges(font):
 data=font.read_bytes();count=struct.unpack_from('>H',data,4)[0]
 tables={data[12+16*i:16+16*i].decode():struct.unpack_from('>II',data,20+16*i) for i in range(count)}
 offset,_=tables['cmap'];count=struct.unpack_from('>H',data,offset+2)[0]
 for i in range(count):
  sub=offset+struct.unpack_from('>I',data,offset+8+8*i)[0]
  if struct.unpack_from('>H',data,sub)[0]==12:
   size=struct.unpack_from('>I',data,sub+12)[0]
   return [struct.unpack_from('>III',data,sub+16+12*j) for j in range(size)]
 raise ValueError('No full Unicode cmap')
copy=read(ROOT/'source/strings.json')
all_text=''.join(copy.values())+(ROOT/'source/locale.js').read_text()
required={ord(c) for c in all_text if 0x2e80<=ord(c)<=0x9fff or 0xff00<=ord(c)<=0xffef}
fonts=[]
for font in sorted((ROOT/'fonts').glob('*.otf')):
 ranges=format12_ranges(font)
 missing=[hex(c) for c in required if not any(start<=c<=end and glyph+c-start>0 for start,end,glyph in ranges)]
 assert not missing,(font.name,missing)
 fonts.append({'file':font.name,'bytes':font.stat().st_size,'sha256':digest(font),'requiredCJKGlyphs':len(required),'missing':missing})
assert len(fonts)==3
for md in ROOT.rglob('*.md'):
 for target in re.findall(r'\]\(([^)]+)\)',md.read_text()):
  if not re.match(r'^[a-z]+:',target) and not target.startswith('#'):
   resolved=(md.parent/target.split('#')[0]).resolve()
   if resolved!=(ROOT/'source/package_checks.json').resolve():assert resolved.exists(),(md,target)
assert not subprocess.check_output(['git','diff','--name-only','--','project.godot','src','localization','tests'],cwd=REPO,text=True).strip()
report={'scope':'Review artifacts only; runtime language support not implemented','screens':36,'languageSpecimens':2,'nativeFrames':38,'choreographyCases':12,'fixtureStructuresIdentical':True,'localeRoundtripPassed':True,'runtimeKeysInventoried':962,'runtimeCatalogComplete':False,'fonts':fonts,'pngHashes':{str(p.relative_to(ROOT)):digest(p) for p in sorted(ROOT.rglob('*.png'))}}
(ROOT/'source/package_checks.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ('fonts','pngHashes')}))
