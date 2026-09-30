/* A design review viewer. It never calls, imitates or replaces the game Domain. */
const SCREENS=window.FT_REVIEW.screens, LEDGER=window.FT_REVIEW.ledger;
let active=SCREENS[0];
const stage=document.getElementById('stage'), list=document.getElementById('screen-list');
function size(e,d){if(d.w)e.style.width=d.w+'px';if(d.h)e.style.height=d.h+'px';}
function build(d){
 let e;
 if(d.type==='text'){
  e=document.createElement('p');e.className='text'+(d.serif?' serif':'')+(d.size===18?' section':'');e.textContent=d.text;e.style.setProperty('--font-size',(d.size||16)+'px');e.style.setProperty('--line',(d.size===26?34:d.size===32?40:d.size===14?20:24)+'px');e.style.color='var(--ft-'+(d.color||'text')+')';size(e,d);return e;
 }
 if(d.type==='button'){
  e=document.createElement('button');e.className='action';e.textContent=d.text;e.dataset.state=d.state;if(d.role)e.dataset.role=d.role;e.disabled=d.state==='disabled';e.setAttribute('aria-label',d.text);size(e,{w:d.w});e.addEventListener('click',()=>{document.getElementById('review-feedback').textContent='Review selection: '+d.text+'. No game action was executed.';if(!/Back|Cancel|Close|Help|Inspect|New Run|Settle|Choose|Buy|Transform|Finish|End Turn|Draw|Return|Take|Review|Dismiss/.test(d.text)){e.dataset.state='selectedFocused';}});return e;
 }
 if(d.type==='tile'){
  e=document.createElement('button');e.className='tile';e.dataset.state=d.state;e.setAttribute('aria-label',({BAM:'Bamboo',DOT:'Dots',CHR:'Characters',HON:'Honor'}[d.suit])+' '+d.rank+(d.instanceLabel?', '+d.instanceLabel:''));const glyph=d.suit==='HON'?({E:'東',W:'白',N:'北',S:'南',R:'中',G:'發'}[d.rank]||'東'):d.suit==='CHR'?'萬':d.suit==='DOT'?'●':'╎╎';for(const [cls,value] of [['rank',d.rank],['glyph',glyph],['suit',d.suit]]){const span=document.createElement('span');span.className=cls;span.textContent=value;e.append(span);}e.addEventListener('click',()=>{e.dataset.state=e.dataset.state==='selected'?'selectedFocused':'selected';document.getElementById('review-feedback').textContent='Tile inspected: '+e.getAttribute('aria-label')+'. Instance selection is illustrative.';});return e;
 }
 if(d.type==='map'){
  e=document.createElement('div');e.className='map';size(e,d);
  const pos=[[12,132,'Intro\nCurrent','current'],[110,60,'Battle\nLeft','selectedFocused'],[110,212,'Battle\nRight','default'],[218,12,'Shop','disabled'],[326,176,'Workshop','disabled'],[218,100,'Event\nLeft','disabled'],[218,264,'Event\nRight','disabled'],[430,132,'Battle\nMid','disabled'],[528,60,'Elite','disabled'],[528,212,'Boss','disabled']];
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('width',d.w);svg.setAttribute('height',d.h);
  for(const [a,b] of [[0,1],[0,2],[1,3],[1,5],[2,4],[2,6],[3,4],[4,7],[5,7],[6,7],[7,8],[8,9]]){const line=document.createElementNS(svg.namespaceURI,'line');for(const [k,v] of Object.entries({x1:pos[a][0]+38,y1:pos[a][1]+26,x2:pos[b][0]+38,y2:pos[b][1]+26,stroke:a===0?'#D8B875':'#6B877B','stroke-width':a===0?2:1}))line.setAttribute(k,v);if(a!==0)line.setAttribute('stroke-dasharray','4 4');svg.append(line);}e.append(svg);
  for(const [x,y,label,state] of pos){const n=build({type:'button',text:label,w:76,h:52,state});n.classList.add('map-node');n.style.left=x+'px';n.style.top=y+'px';e.append(n);}const legend=document.createElement('span');legend.className='map-legend';legend.textContent='Current · Reachable: left / right · Later nodes unavailable';e.append(legend);return e;
 }
 e=document.createElement('div');e.className=d.type==='screen'?'screen':d.type==='panel'?'panel':'layout '+d.type;size(e,d);e.style.gap=(d.gap??8)+'px';if(d.state)e.dataset.state=d.state;if(d.name)e.setAttribute('aria-label',d.name);for(const child of d.children||[])e.append(build(child));return e;
}
function expandedSheet(scale){
 const src=SCREENS.find(s=>s.slug==='pseudo-expansion');const e=build(src.tree);e.classList.add('expanded-sheet');if(scale===1.5)e.classList.add('large-text');e.children[0].querySelector('.serif').classList.add('screen-title');e.children[2].classList.add('sheet-message');e.children[3].classList.add('sheet-footer');e.setAttribute('aria-label','Expanded localized detail sheet specimen');return e;
}
function show(slug){
 active=SCREENS.find(s=>s.slug===slug)||SCREENS[0];const specimen=document.getElementById('specimen').value;stage.replaceChildren();let e=specimen==='expanded'?expandedSheet(1.25):specimen==='large-text'?expandedSheet(1.5):build(active.tree);
 if(['wide','deck','desktop'].includes(specimen)){const v=document.createElement('div');v.className='viewport';const dims={wide:[1280,720],deck:[1280,800],desktop:[1920,1080]}[specimen];v.style.width=dims[0]+'px';v.style.height=dims[1]+'px';v.append(e);stage.append(v);}else stage.append(e);
 stage.dataset.screen=active.slug;document.getElementById('notes').textContent=active.id+' · '+active.title+' — '+active.notes;for(const n of list.children)n.setAttribute('aria-current',String(n.dataset.slug===active.slug));document.getElementById('static-image').href='mockups/'+active.id+'-'+active.slug+'.png';const f=LEDGER.frames.find(f=>f.slug===active.slug);document.getElementById('figma-frame').href='https://www.figma.com/design/'+LEDGER.fileKey+'?node-id='+f.id.replace(':','-');document.getElementById('review-feedback').textContent='';location.hash=active.slug;window.FT_ACTIVE=active.slug;
}
for(const s of SCREENS){const b=document.createElement('button');b.textContent=s.id+' · '+s.title;b.dataset.slug=s.slug;b.addEventListener('click',()=>show(s.slug));list.append(b);}
document.getElementById('specimen').addEventListener('change',()=>show(active.slug));document.getElementById('mode').addEventListener('change',()=>{document.getElementById('receipt-text').textContent='Complete Hand settled. → Boss enters phase 2. → Victory!';document.getElementById('review-feedback').textContent=document.getElementById('mode').value+' review: the same ordered receipt remains visible.';});
window.FT_SHOW=show;window.FT_BUILD=build;
show(location.hash.slice(1)||SCREENS[0].slug);
