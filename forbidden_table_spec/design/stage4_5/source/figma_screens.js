// Reads an embedded design-fixture subset and builds editable native Figma layers.
const ledger = __LEDGER__, screens = __SCREENS__;
const page = await figma.getNodeByIdAsync(__PAGE__);
await figma.setCurrentPageAsync(page);
if(page.children.some(n=>n.name.startsWith(screens[0].id+' ·'))) throw new Error('These screens already exist; inspect ledger before retry.');
for(const f of [{family:'Noto Sans',style:'Regular'},{family:'Noto Sans',style:'SemiBold'},{family:'Noto Serif',style:'Regular'},{family:'Noto Sans SC',style:'Regular'}]) await figma.loadFontAsync(f);
const created=[], frames=[], track=n=>{created.push(n.id);return n;};
const vars={};for(const [k,id] of Object.entries(ledger.variables)) vars[k]=await figma.variables.getVariableByIdAsync(id);
const paint=k=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',vars[k]);
const buttonSet=await figma.getNodeByIdAsync(ledger.buttonSet),tileSet=await figma.getNodeByIdAsync(ledger.tileSet);
function text(d) {
 const t=track(figma.createText());t.name=d.text.slice(0,70);t.fontName={family:d.serif?'Noto Serif':'Noto Sans',style:!d.serif&&d.size===18?'SemiBold':'Regular'};t.fontSize=d.size||16;t.lineHeight={unit:'PIXELS',value:d.size===26?34:d.size===32?40:d.size===14?20:24};t.characters=d.text;t.fills=[paint(d.color||'text')];t.textAutoResize='HEIGHT';t.resize(d.w||400,t.height);
 const role=d.serif?(d.size===32?'Outcome':'Title'):d.size===14?'Secondary':d.size===18?'Section':'Body';t.textStyleId=ledger.styles[role];return t;
}
function instance(d) {
 const component=d.type==='button'?buttonSet.children.find(c=>c.name==='State='+d.state):tileSet.children.find(c=>c.name==='Suit='+d.suit+', State='+d.state);
 if(!component) throw new Error('Missing component: '+JSON.stringify(d));
 const i=track(component.createInstance());i.name=d.type==='button'?d.text:d.suit+' '+d.rank;i.resize(d.w,d.h);
 const props={};for(const key of Object.keys(i.componentProperties)) {
  if(d.type==='button'&&key.startsWith('Label#')) props[key]=d.text;
  if(d.type==='tile') {
   if(key.startsWith('Rank#'))props[key]=d.rank;
   if(key.startsWith('Glyph#'))props[key]=d.suit==='HON'?({E:'東',W:'白',N:'北',S:'南',R:'中',G:'發'}[d.rank]||'東'):d.suit==='CHR'?'萬':d.suit==='DOT'?'●':'| |';
   if(key.startsWith('Suit#'))props[key]=d.suit;
  }
 }
 i.setProperties(props);
 if(d.type==='button') {
  const label=i.findOne(n=>n.type==='TEXT');label.textAutoResize='HEIGHT';label.layoutSizingHorizontal='FILL';label.textAlignHorizontal='CENTER';i.counterAxisSizingMode='AUTO';i.minHeight=44;
 }
 if(d.role==='commit'&&d.state!=='disabled'){i.fills=[paint('brass')];const label=i.findOne(n=>n.type==='TEXT');label.fills=[paint('ink')];}
 // Selection remains a brass edge and focus adds an outer cyan perimeter.
 if(d.state==='selectedFocused') i.effects=[{type:'DROP_SHADOW',color:{r:0.627,g:0.906,b:0.937,a:1},offset:{x:0,y:0},radius:0,spread:3,visible:true,blendMode:'NORMAL'}];
 return i;
}
function map(d) {
 const f=track(figma.createFrame());f.name='Existing 10-node topology';f.resize(d.w,d.h);f.fills=[paint('panel')];f.cornerRadius=8;f.clipsContent=false;
 const pos=[[12,132,'Intro\nCurrent','current'],[110,60,'Battle\nLeft','selectedFocused'],[110,212,'Battle\nRight','default'],[218,12,'Shop','disabled'],[326,176,'Workshop','disabled'],[218,100,'Event\nLeft','disabled'],[218,264,'Event\nRight','disabled'],[430,132,'Battle\nMid','disabled'],[528,60,'Elite','disabled'],[528,212,'Boss','disabled']];
 for(const [a,b] of [[0,1],[0,2],[1,3],[1,5],[2,4],[2,6],[3,4],[4,7],[5,7],[6,7],[7,8],[8,9]]) {
  const x1=pos[a][0]+38,y1=pos[a][1]+26,x2=pos[b][0]+38,y2=pos[b][1]+26;
  const v=track(figma.createVector());v.name='Catalog edge '+a+' to '+b;v.vectorPaths=[{windingRule:'NONE',data:`M ${x1} ${y1} L ${x2} ${y2}`}];v.strokes=[paint(a===0?'brass':'edge')];v.strokeWeight=a===0?2:1;v.fills=[];f.appendChild(v);
 }
 for(const [x,y,label,state] of pos) {
  const n=track(figma.createAutoLayout('VERTICAL'));n.name=label.replace('\n',' ')+' · '+state;n.resize(76,52);n.primaryAxisSizingMode='FIXED';n.counterAxisSizingMode='FIXED';n.primaryAxisAlignItems='CENTER';n.counterAxisAlignItems='CENTER';n.fills=[paint(state==='disabled'?'table':'raised')];n.strokes=[paint(state==='selected'?'brass':state==='focused'?'focus':'edge')];n.strokeWeight=state==='focused'?3:1;n.cornerRadius=state==='selected'?16:6;f.appendChild(n);n.x=x;n.y=y;const t=text({text:label,w:70,size:14,color:state==='disabled'?'muted':'text'});t.textAlignHorizontal='CENTER';n.appendChild(t);
 }
 const legend=text({text:'Current · Reachable: left / right · Later nodes unavailable',w:584,size:14,color:'muted'});f.appendChild(legend);legend.x=16;legend.y=324;return f;
}
function render(d) {
 if(d.type==='text')return text(d);
 if(d.type==='button'||d.type==='tile')return instance(d);
 if(d.type==='map')return map(d);
 const n=track(figma.createAutoLayout(d.type==='row'?'HORIZONTAL':'VERTICAL'));n.name=d.name||d.type;n.resize(d.w||928,d.h||1);n.primaryAxisSizingMode=d.type==='row'?'FIXED':d.h?'FIXED':'AUTO';n.counterAxisSizingMode=d.type==='row'&&!d.h?'AUTO':'FIXED';n.itemSpacing=d.gap??8;n.fills=d.type==='screen'?[paint('table')]:d.type==='panel'?[paint('panel')]:[];n.clipsContent=false;
 if(d.type==='panel'){n.paddingTop=12;n.paddingBottom=12;n.paddingLeft=12;n.paddingRight=12;n.cornerRadius=8;n.strokes=[paint('edge')];n.strokeWeight=d.state==='selected'?2:1;if(d.state==='selected')n.strokes=[paint('brass')];}
 if(d.type==='screen'){n.paddingTop=16;n.paddingBottom=16;n.paddingLeft=16;n.paddingRight=16;n.clipsContent=true;}
 for(const child of d.children||[])n.appendChild(render(child));return n;
}
const startIndex=page.children.filter(n=>n.type==='FRAME'&&/^\d\d ·/.test(n.name)).length;
for(const [localIndex,s] of screens.entries()) {
 const index=startIndex+localIndex;
 const f=render(s.tree);f.name=s.id+' · '+s.slug+' · Proposed v1';page.appendChild(f);f.x=40+(index%3)*1024;f.y=40+Math.floor(index/3)*636;frames.push({id:f.id,screen:s.id,slug:s.slug,w:f.width,h:f.height,textCount:f.findAllWithCriteria({types:['TEXT']}).length,instanceCount:f.findAllWithCriteria({types:['INSTANCE']}).length});
 const caption=text({text:s.id+' · '+s.title+'  |  PROPOSED v1',w:960,size:14,color:'muted'});page.appendChild(caption);caption.x=f.x;caption.y=f.y+552;
}
return {pageId:page.id,frames,createdNodeIds:created,mutatedNodeIds:[],fonts:['Noto Sans','Noto Serif','Noto Sans SC'],editable:true};
