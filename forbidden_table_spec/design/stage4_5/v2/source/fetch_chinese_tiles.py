"""Fetch unmodified Chinese Mahjong face assets pinned to their upstream commit."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,subprocess,struct
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/chinese-tiles';DEST.mkdir(exist_ok=True)
SHA='7629eeeba620ba9f0a98907bc40c0776523af989'
BASE=f'https://raw.githubusercontent.com/zddd312/mahjong-tiles/{SHA}'
def fetch(name):
 target=DEST/name
 if not target.exists():
  win='C:'+str(target).removeprefix('/mnt/c')
  subprocess.run(['/mnt/c/Windows/System32/curl.exe','--silent','--show-error','--fail','--location','--retry','3','--retry-all-errors','--connect-timeout','15','--max-time','60','--output',win,BASE+('/'+name if name=='LICENSE' else '/tiles/'+name)],check=True)
 if name.endswith('.png'):
  width,height=struct.unpack('>II',target.read_bytes()[16:24])
  assert 260<=width<=280 and height==360,(name,width,height)
 return target
names=[f'{r}{s}.png' for s in ['m','p','s'] for r in range(1,10)]+[f'z{r}.png' for r in range(1,8)]+['LICENSE']
with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(fetch,names))
assets=[]
for suit,letter in [('CHR','m'),('DOT','p'),('BAM','s')]:
 for rank in range(1,10):
  name=f'{rank}{letter}.png';assets.append(dict(key=f'{suit}:{rank}',suit=suit,rank=str(rank),file=name))
for rank,english,source in [('E','East',1),('S','South',2),('WEST','West',3),('N','North',4),('R','Red dragon',5),('G','Green dragon',6),('W','White dragon',7)]:
 assets.append(dict(key=f'HON:{rank}',suit='HON',rank=rank,honor=english,file=f'z{source}.png'))
for a in assets:
 a.update(sha256=hashlib.sha256((DEST/a['file']).read_bytes()).hexdigest(),source=BASE+'/tiles/'+a['file'],size=list(struct.unpack('>II',(DEST/a['file']).read_bytes()[16:24])))
 a['definitionId']='base.tile.'+({'CHR':'characters','DOT':'dots','BAM':'bamboo'}[a['suit']]+'.'+a['rank'] if a['suit']!='HON' else 'honors.'+a['honor'].removesuffix(' dragon').lower())
manifest=dict(repository='https://github.com/zddd312/mahjong-tiles',commit=SHA,license='M+ font license; see LICENSE',originalSize=[272,360],modifications='None; displayed with contain scaling',assets=assets)
(DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'faces':len(assets),'commit':SHA,'licenseSaved':(DEST/'LICENSE').exists()}))
