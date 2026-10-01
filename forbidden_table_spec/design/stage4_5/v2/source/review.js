/* A design review viewer. It never calls, imitates or replaces the game Domain. */
const SCREENS=window.FT_V2.screens, LEDGER=window.FT_V2.ledger||{frames:[],fileKey:"xXzt7gEelGQh37Ak51ogGa"};
const TILE_FACES=Object.fromEntries((window.FT_V2.chineseTiles?.assets||[]).map(a=>[a.key,a.file]));
let active=SCREENS[0];
let running=[],playToken=0;
function cancelMotion(){playToken++;for(const a of running)a.cancel();running=[];document.querySelectorAll(".demo-stamp").forEach(n=>n.remove());}
const stage=document.getElementById('stage'), list=document.getElementById('screen-list');
function size(e,d){if(d.w)e.style.width=d.w+'px';if(d.h)e.style.height=d.h+'px';}
function build(d){
 let e;
 if(d.type==='sigil'){e=document.createElement('div');e.className='relic-emblem';size(e,d);e.innerHTML='<svg viewBox="0 0 130 96" aria-hidden="true"><circle cx="65" cy="48" r="39" fill="#203728" stroke="#e7b65a" stroke-width="2"/><circle cx="65" cy="48" r="31" fill="none" stroke="#9e865a" stroke-dasharray="2 5"/><path d="M65 19 L86 48 L65 77 L44 48 Z M44 48 H86 M65 19 V77" fill="#ca9a4238" stroke="#e7b65a" stroke-width="2"/></svg><span></span>';e.querySelector('span').textContent=d.kind;return e;}
 if(d.type==='text'){
  e=document.createElement('p');e.className='text'+(d.serif?' serif':'')+(d.size===18?' section':'');e.textContent=d.text;e.style.setProperty('--font-size',(d.size||16)+'px');e.style.setProperty('--line',(d.size===26?34:d.size===32?40:d.size===24?30:d.size===14?20:24)+'px');e.style.color='var(--ft-'+(d.color||'text')+')';size(e,d);return e;
 }
 if(d.type==='button'){
  e=document.createElement('button');e.className='action';e.textContent=d.text;e.dataset.state=d.state;if(d.role)e.dataset.role=d.role;e.disabled=d.state==='disabled';e.setAttribute('aria-label',d.text);size(e,{w:d.w});e.addEventListener('click',()=>{document.getElementById('review-feedback').textContent='Review selection: '+d.text+'. No game action was executed.';if(!/Back|Cancel|Close|Help|Inspect|New Run|Settle|Choose|Buy|Transform|Finish|End Turn|Draw|Return|Take|Review|Dismiss/.test(d.text)){e.dataset.state='selectedFocused';}});return e;
 }
 if(d.type==='tile'){
  e=document.createElement('button');e.className='tile'+(d.large?' large':'');size(e,d);e.dataset.state=d.state;const key=d.suit+':'+d.rank,file=TILE_FACES[key];if(!file)throw new Error('Missing Chinese tile face '+key);e.dataset.face=key;const label=d.suit==='HON'?({E:'East',S:'South',WEST:'West',N:'North',R:'Red dragon',G:'Green dragon',W:'White dragon'}[d.rank]):({BAM:'Bamboo',DOT:'Dots',CHR:'Characters'}[d.suit])+' '+d.rank;e.setAttribute('aria-label',label+(d.instanceLabel?', '+d.instanceLabel:''));const img=document.createElement('img');img.src='assets/chinese-tiles/'+file;img.alt='';img.draggable=false;e.append(img);e.addEventListener('click',()=>{e.dataset.state=e.dataset.state==='selected'?'selectedFocused':'selected';document.getElementById('review-feedback').textContent='Tile inspected: '+e.getAttribute('aria-label')+'. Instance selection is illustrative.';});return e;
 }
 if(d.type==='map'){
  e=document.createElement('div');e.className='map';size(e,d);
  const pos=[[12,132,'Intro\nCurrent','current'],[110,60,'Battle\nLeft','selectedFocused'],[110,212,'Battle\nRight','default'],[218,12,'Shop','disabled'],[326,176,'Workshop','disabled'],[218,100,'Event\nLeft','disabled'],[218,264,'Event\nRight','disabled'],[430,132,'Battle\nMid','disabled'],[528,60,'Elite','disabled'],[528,212,'Boss','disabled']];
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('width',d.w);svg.setAttribute('height',d.h);
  for(const [a,b] of [[0,1],[0,2],[1,3],[1,5],[2,4],[2,6],[3,4],[4,7],[5,7],[6,7],[7,8],[8,9]]){const line=document.createElementNS(svg.namespaceURI,'line');for(const [k,v] of Object.entries({x1:pos[a][0]+38,y1:pos[a][1]+26,x2:pos[b][0]+38,y2:pos[b][1]+26,stroke:a===0?'#D8B875':'#6B877B','stroke-width':a===0?2:1}))line.setAttribute(k,v);if(a!==0)line.setAttribute('stroke-dasharray','4 4');svg.append(line);}e.append(svg);
  for(const [x,y,label,state] of pos){const n=build({type:'button',text:label,w:76,h:52,state});n.classList.add('map-node');n.style.left=x+'px';n.style.top=y+'px';e.append(n);}const legend=document.createElement('span');legend.className='map-legend';legend.textContent='Current · Reachable: left / right · Later nodes unavailable';e.append(legend);return e;
 }
 e=document.createElement('div');e.className=d.type==='screen'?'screen':d.type==='panel'?'panel':'layout '+d.type;size(e,d);e.style.gap=(d.gap??8)+'px';if(d.align==='center'){e.style.justifyContent='center';e.style.alignItems='center';}if(d.surface)e.dataset.surface=d.surface;if(d.portrait!==undefined)e.style.setProperty('--portrait-position',(d.portrait*50)+'%');if(d.state)e.dataset.state=d.state;if(d.name)e.setAttribute('aria-label',d.name);for(const child of d.children||[])e.append(build(child));return e;
}
function expandedSheet(scale){
 const src=SCREENS.find(s=>s.slug==='pseudo-expansion');const e=build(src.tree);e.classList.add('expanded-sheet');if(scale===1.5)e.classList.add('large-text');e.children[0].querySelector('.serif').classList.add('screen-title');e.children[2].classList.add('sheet-message');e.children[3].classList.add('sheet-footer');e.setAttribute('aria-label','Expanded localized detail sheet specimen');return e;
}
function show(slug){
 cancelMotion();document.getElementById('motion-caption').textContent='Choose a motion study and Replay. All game values are illustrative.';active=SCREENS.find(s=>s.slug===slug)||SCREENS[0];const specimen=document.getElementById('specimen').value;stage.replaceChildren();let e=specimen==='expanded'?expandedSheet(1.25):specimen==='large-text'?expandedSheet(1.5):build(active.tree);
 if(['wide','deck','desktop'].includes(specimen)){const v=document.createElement('div');v.className='viewport';const dims={wide:[1280,720],deck:[1280,800],desktop:[1920,1080]}[specimen];v.style.width=dims[0]+'px';v.style.height=dims[1]+'px';v.append(e);stage.append(v);}else stage.append(e);
 stage.dataset.screen=active.slug;document.getElementById('notes').textContent=active.id+' · '+active.title+' — '+active.notes;for(const n of list.children)n.setAttribute('aria-current',String(n.dataset.slug===active.slug));document.getElementById('static-image').href='mockups/'+active.id+'-'+active.slug+'.png';const f=LEDGER.frames.find(f=>f.slug===active.slug);document.getElementById('figma-frame').href='https://www.figma.com/design/'+LEDGER.fileKey+(f?'?node-id='+f.id.replace(':','-'):'');document.getElementById('review-feedback').textContent='';location.hash=active.slug;window.FT_ACTIVE=active.slug;
}
for(const s of SCREENS){const b=document.createElement('button');b.textContent=s.id+' · '+s.title;b.dataset.slug=s.slug;b.addEventListener('click',()=>show(s.slug));list.append(b);}
document.getElementById('specimen').addEventListener('change',()=>show(active.slug));document.getElementById('mode').addEventListener('change',()=>{cancelMotion();document.getElementById('receipt-text').textContent='Complete Hand settled. → Boss enters phase 2. → Victory!';document.getElementById('review-feedback').textContent=document.getElementById('mode').value+' review: the same ordered receipt remains visible.';});
window.FT_SHOW=show;window.FT_BUILD=build;
show(location.hash.slice(1)||SCREENS[0].slug);

const reduced=document.getElementById('reduced');reduced.checked=matchMedia('(prefers-reduced-motion: reduce)').matches;
function preferences(){cancelMotion();document.body.dataset.reduced=String(reduced.checked);document.body.dataset.instant=String(document.getElementById('mode').value==='Instant');document.body.dataset.ambient=String(document.getElementById('ambient').checked&&!reduced.checked&&document.getElementById('mode').value!=='Instant');}
for(const id of ['reduced','ambient','mode'])document.getElementById(id).addEventListener('change',preferences);preferences();
function animate(el,keyframes,options){if(!el)return null;const a=el.animate(keyframes,options);running.push(a);return a;}
async function playDemo(){
 const kind=document.getElementById('motion').value;const slug={draw:'battle-table',settlement:'critical-feedback',reward:'reward-normal',workshop:'workshop-value'}[kind];show(slug);const token=playToken;const mode=document.getElementById('mode').value;const duration=reduced.checked||mode==='Instant'?0:mode==='Fast'?240:600;
 document.getElementById('review-feedback').textContent='Playing '+kind+' · '+mode+' · illustration only; no command or state change.';
 const root=stage.querySelector('.screen'), tiles=[...root.querySelectorAll('.tile')];
 if(kind==='draw')animate(tiles[tiles.length-1],[{transform:'translate(90px,-96px) rotate(9deg)',opacity:0},{transform:'translate(0,0) rotate(0)',opacity:1}],{duration,easing:'cubic-bezier(.16,1,.3,1)'});
 if(kind==='workshop')for(const [i,t] of tiles.entries())animate(t,[{transform:i?'translateY(-12px) scale(.92)':'translateY(0)',opacity:i?.35:1},{transform:'translateY(0) scale(1)',opacity:1}],{duration,easing:'cubic-bezier(.16,1,.3,1)'});
 if(kind==='reward')for(const [i,c] of [...root.querySelectorAll('[data-surface=reward]')].entries())animate(c,[{transform:'translateY(18px) rotate(-2deg)',opacity:0},{transform:'translateY(0) rotate(0)',opacity:1}],{duration:duration*.7,delay:duration?i*duration*.15:0,easing:'cubic-bezier(.16,1,.3,1)'});
 if(kind==='settlement'){
  for(const t of tiles.slice(0,3))animate(t,[{transform:'translateY(0)'},{transform:'translateY(-12px)',offset:.5},{transform:'translateY(0)'}],{duration:duration*.6,easing:'ease-out'});
  const stamp=document.createElement('div');stamp.className='demo-stamp';stamp.setAttribute('aria-hidden','true');stamp.textContent='HAND SETTLED';root.append(stamp);
  const captions=['Complete Hand settled.','Boss enters phase 2.','Victory!'];
  // Persistent ordered receipt exists before playback; this is cosmetic emphasis only.
  animate(stamp,[{opacity:0,transform:'scale(1.12)'},{opacity:1,transform:'scale(1)'}],{duration:duration*.35,easing:'ease-out'});
  for(let i=0;i<3;i++){if(token!==playToken)return;stamp.textContent=['HAND SETTLED','BOSS · PHASE 2','VICTORY'][i];document.getElementById('motion-caption').textContent=captions.slice(0,i+1).join(' → ');if(duration)await new Promise(r=>setTimeout(r,duration*.65));}
  if(token===playToken)stamp.remove();
 }
 if(token===playToken)document.getElementById('motion-caption').textContent=kind==='settlement'?'Complete Hand settled. → Boss enters phase 2. → Victory!':'Final readable state · '+kind+' animation study. No game action executed.';
}
document.getElementById('play').addEventListener('click',playDemo);document.getElementById('stop').addEventListener('click',()=>{cancelMotion();document.getElementById('motion-caption').textContent='Stopped at readable static state.';});document.addEventListener('keydown',e=>{if(e.key==='Escape')cancelMotion();});
window.FT_V2_DEMO=playDemo;window.FT_V2_STOP=cancelMotion;
