// Reads an embedded design-fixture subset and builds editable native Figma layers.
const ledger = __LEDGER__, screens = __SCREENS__;
const page = await figma.getNodeByIdAsync(__PAGE__);
await figma.setCurrentPageAsync(page);
// Destination root identities are inspected before any mutation.
for(const f of [{family:'Noto Sans',style:'Regular'},{family:'Noto Sans',style:'SemiBold'},{family:'Noto Serif',style:'Regular'},{family:'Noto Sans SC',style:'Regular'}]) await figma.loadFontAsync(f);
const created=[], frames=[], track=n=>{created.push(n.id);return n;};
const vars={};for(const [k,id] of Object.entries(ledger.variables)) vars[k]=await figma.variables.getVariableByIdAsync(id);
const palette=__PALETTE__;
const paint=k=>{const h=palette[k];if(!h)throw new Error('Missing palette '+k);const color={r:parseInt(h.slice(1,3),16)/255,g:parseInt(h.slice(3,5),16)/255,b:parseInt(h.slice(5,7),16)/255};return figma.variables.setBoundVariableForPaint({type:'SOLID',color},'color',vars[k]);};
const art=ledger.art;
const rgba=(h,a=1)=>({r:parseInt(h.slice(1,3),16)/255,g:parseInt(h.slice(3,5),16)/255,b:parseInt(h.slice(5,7),16)/255,a});
const gradient=(top,bottom,alpha=1)=>({type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:rgba(top,alpha)},{position:1,color:rgba(bottom,alpha)}]});
const shadow={type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:.45},offset:{x:0,y:4},radius:6,spread:0,visible:true,blendMode:'NORMAL'};
const buttonSet=await figma.getNodeByIdAsync(ledger.buttonSet),tileSet=await figma.getNodeByIdAsync(ledger.tileSet);
function text(d) {
 const t=track(figma.createText());t.name=d.text.slice(0,70);t.fontName={family:d.serif?'Noto Serif':'Noto Sans',style:!d.serif&&d.size===18?'SemiBold':'Regular'};t.fontSize=d.size||16;t.lineHeight={unit:'PIXELS',value:d.size===26?34:d.size===32?40:d.size===14?20:24};t.characters=d.text;t.fills=[paint(d.color||'text')];t.textAutoResize='HEIGHT';t.resize(d.w||400,t.height);
 const role=d.serif?(d.size===32?'Outcome':'Title'):d.size===14?'Secondary':d.size===18?'Section':'Body';t.textStyleId=ledger.styles[role];t.fontSize=d.size||16;t.lineHeight={unit:'PIXELS',value:d.size===32?40:d.size===26?34:d.size===24?30:d.size===14?20:24};t.fills=[paint(d.color||'text')];return t;
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
 i.setProperties(props);i.cornerRadius=d.type==='button'?3:4;i.effects=[shadow];i.strokes=[paint(d.state==='selected'||d.state==='selectedFocused'?'brass':'edge')];i.strokeWeight=d.state==='selected'||d.state==='selectedFocused'?2:1;i.fills=[gradient(d.type==='tile'?'#FFF5DF':'#294332',d.type==='tile'?'#DFD4B3':'#152B20')];if(d.state==='disabled'){i.dashPattern=[4,3];i.fills=[paint('raised')];}for(const t of i.findAllWithCriteria({types:['TEXT']}))t.fills=[paint(d.type==='tile'?'ink':d.state==='disabled'?'muted':'text')];
 if(d.type==='button') {
  const label=i.findOne(n=>n.type==='TEXT');label.textAutoResize='HEIGHT';label.layoutSizingHorizontal='FILL';label.textAlignHorizontal='CENTER';i.counterAxisSizingMode='AUTO';i.minHeight=44;
 }
 if((d.role==='commit'||d.state==='primary')&&d.state!=='disabled'){i.fills=[gradient('#F3CF82','#D4A44E')];const label=i.findOne(n=>n.type==='TEXT');label.fills=[paint('ink')];}
 // Selection remains a brass edge and focus adds an outer cyan perimeter.
 if(d.state==='focused'||d.state==='selectedFocused'){const ring=i.findOne(n=>n.type==='RECTANGLE'&&n.name.startsWith('Focus perimeter'));if(!ring)throw new Error('Missing native focus perimeter');ring.strokes=[paint('focus')];/* Native component perimeter stretches with the instance. */}
 if(d.type==='tile'){
  const key=d.suit+':'+d.rank,hash=ledger.tileFaces?.images[key];if(!hash)throw new Error('Missing Chinese face '+key);
  for(const t of i.findAllWithCriteria({types:['TEXT']}))t.visible=false;
  i.primaryAxisSizingMode='FIXED';i.counterAxisSizingMode='FIXED';
  i.fills=[{type:'SOLID',color:{r:1,g:.961,b:.875}},{type:'IMAGE',imageHash:hash,scaleMode:'FIT'}];
 }
 return i;
}
function map(d) {
 const f=track(figma.createFrame());f.name='Existing 10-node topology';f.resize(d.w,d.h);f.fills=[gradient('#244535','#14281F',.93)];f.cornerRadius=4;f.clipsContent=false;
 const pos=[[12,132,'Intro\nCurrent','current'],[110,60,'Battle\nLeft','selectedFocused'],[110,212,'Battle\nRight','default'],[218,12,'Shop','disabled'],[326,176,'Workshop','disabled'],[218,100,'Event\nLeft','disabled'],[218,264,'Event\nRight','disabled'],[430,132,'Battle\nMid','disabled'],[528,60,'Elite','disabled'],[528,212,'Boss','disabled']];
 for(const [a,b] of [[0,1],[0,2],[1,3],[1,5],[2,4],[2,6],[3,4],[4,7],[5,7],[6,7],[7,8],[8,9]]) {
  const x1=pos[a][0]+38,y1=pos[a][1]+26,x2=pos[b][0]+38,y2=pos[b][1]+26;
  const v=track(figma.createVector());v.name='Catalog edge '+a+' to '+b;v.vectorPaths=[{windingRule:'NONE',data:`M ${x1} ${y1} L ${x2} ${y2}`}];v.strokes=[paint(a===0?'brass':'edge')];v.strokeWeight=a===0?2:1;v.dashPattern=a===0?[]:[4,4];v.fills=[];f.appendChild(v);
 }
 for(const [x,y,label,state] of pos) {
  const n=track(figma.createAutoLayout('VERTICAL'));n.name=label.replace('\n',' ')+' · '+state;n.resize(76,52);n.primaryAxisSizingMode='FIXED';n.counterAxisSizingMode='FIXED';n.primaryAxisAlignItems='CENTER';n.counterAxisAlignItems='CENTER';n.fills=[paint(state==='disabled'?'table':'raised')];n.strokes=[paint(state==='current'||state==='selectedFocused'?'brass':state==='focused'?'focus':'edge')];n.strokeWeight=state==='current'||state==='selectedFocused'?2:1;n.cornerRadius=state==='current'?24:15;if(state==='disabled')n.dashPattern=[4,3];f.appendChild(n);n.x=x;n.y=y;if(state==='selectedFocused'){const ring=track(figma.createRectangle());ring.name='Focus perimeter';ring.fills=[];ring.strokes=[paint('focus')];ring.strokeWeight=3;ring.strokeAlign='OUTSIDE';ring.cornerRadius=8;n.appendChild(ring);ring.layoutPositioning='ABSOLUTE';ring.resize(80,56);ring.x=-2;ring.y=-2;n.clipsContent=false;}const t=text({text:label,w:70,size:14,color:state==='disabled'?'muted':'text'});t.textAlignHorizontal='CENTER';n.appendChild(t);
 }
 const legend=text({text:'Current · Reachable: left / right · Later nodes unavailable',w:584,size:14,color:'muted'});f.appendChild(legend);legend.x=16;legend.y=324;return f;
}
function render(d) {
 if(d.type==='sigil'){
 const f=track(figma.createAutoLayout('VERTICAL'));f.name=d.kind+' · decorative seal';f.resize(d.w,d.h);f.primaryAxisSizingMode='FIXED';f.counterAxisSizingMode='FIXED';f.primaryAxisAlignItems='CENTER';f.counterAxisAlignItems='CENTER';f.itemSpacing=0;f.fills=[];
 const mark=track(figma.createFrame());mark.name='Engraved seal';mark.resize(130,96);mark.fills=[];f.appendChild(mark);
 for(const r of [39,31]){const e=track(figma.createEllipse());mark.appendChild(e);e.resize(r*2,r*2);e.x=65-r;e.y=48-r;e.fills=r===39?[paint('raised')]:[];e.strokes=[paint(r===39?'brass':'edge')];e.strokeWeight=r===39?2:1;if(r===31)e.dashPattern=[2,5];}
 const v=track(figma.createVector());mark.appendChild(v);v.name='Seal engraving';v.vectorPaths=[{windingRule:'NONE',data:'M 65 19 L 86 48 L 65 77 L 44 48 Z M 44 48 L 86 48 M 65 19 L 65 77'}];v.strokes=[paint('brass')];v.strokeWeight=2;v.fills=[];
 const t=text({text:d.kind,w:d.w,size:14,color:'brass'});t.textAlignHorizontal='CENTER';f.appendChild(t);return f;
 }
 if(d.type==='text')return text(d);
 if(d.type==='button'||d.type==='tile')return instance(d);
 if(d.type==='map')return map(d);
 const n=track(figma.createAutoLayout(d.type==='row'?'HORIZONTAL':'VERTICAL'));n.name=d.name||d.type;n.resize(d.w||928,d.h||1);n.primaryAxisSizingMode=d.type==='row'?'FIXED':d.h?'FIXED':'AUTO';n.counterAxisSizingMode=d.type==='row'&&!d.h?'AUTO':'FIXED';n.itemSpacing=d.gap??8;if(d.align==='center'){n.primaryAxisAlignItems='CENTER';n.counterAxisAlignItems='CENTER';}n.fills=d.type==='screen'?[paint('table')]:d.type==='panel'?[paint('panel')]:[];n.clipsContent=d.type==='panel';
 if(d.type==='panel'){n.paddingTop=12;n.paddingBottom=12;n.paddingLeft=12;n.paddingRight=12;n.cornerRadius=3;n.strokes=[paint('edge')];n.strokeWeight=d.state==='selected'?2:1;if(d.state==='selected')n.strokes=[paint('brass')];}
 if(d.type==='panel'){
 const surfaces={paper:['#30271C','#191A14',.96],table:['#10362C','#0A2019',.72],workshop:['#223326','#171D16',.96],shop:['#33251C','#131B15',.96],chronicle:['#232819','#0C1914',.96],reward:['#233226','#0B1712',.96],lacquer:['#15271E','#0B1915',.96]};
 const c=surfaces[d.surface]||surfaces.lacquer;n.fills=[gradient(...c)];n.effects=[shadow];
 if(d.surface==='portrait'){
  const bg=track(figma.createRectangle());bg.name='Character portrait · cosmetic concept';n.appendChild(bg);bg.layoutPositioning='ABSOLUTE';bg.resize(n.width*3,n.width*3*907/1734);bg.x=-(d.portrait||0)*n.width;bg.y=0;bg.fills=[{type:'IMAGE',imageHash:art.portraits,scaleMode:'FILL',filters:d.state==='disabled'?{saturation:-.65}:undefined}];
  const shade=track(figma.createRectangle());shade.name='Portrait readability scrim';n.appendChild(shade);shade.layoutPositioning='ABSOLUTE';shade.resize(n.width,n.height);shade.x=0;shade.y=0;shade.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:rgba('#08140B',0)},{position:.35,color:rgba('#08140B',.12)},{position:.52,color:rgba('#08140B',.88)},{position:1,color:rgba('#08140B',.96)}]}];
 }
 const corner=track(figma.createVector());corner.name='Carved corner · decoration';corner.vectorPaths=[{windingRule:'NONE',data:'M 0 0 L 13 0 L 13 13'}];corner.strokes=[paint('brass')];corner.strokeWeight=2;corner.fills=[];corner.opacity=.55;n.appendChild(corner);corner.layoutPositioning='ABSOLUTE';corner.x=n.width-21;corner.y=8;
}
if(d.surface==='enemy'){n.fills=[gradient('#331814','#141B16',.96)];n.paddingLeft=6;n.paddingTop=3;}
if(d.name==='Run rail')n.fills=[paint('table')];
if(d.name==='Hand tray')n.fills=[gradient('#183329','#091911',.86)];
if(d.name==='Zone wells')n.fills=[paint('panel')];
if(d.type==='screen'){n.paddingTop=16;n.paddingBottom=16;n.paddingLeft=16;n.paddingRight=16;n.clipsContent=true;n.fills=[{type:'IMAGE',imageHash:art.salon,scaleMode:'FILL'},{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:rgba('#040C09',.8)},{position:.26,color:rgba('#040C09',.18)},{position:.64,color:rgba('#040C09',.24)},{position:1,color:rgba('#040C09',.88)}]}];}
 for(const child of d.children||[]){const available=n.width-n.paddingLeft-n.paddingRight-(n.strokesIncludedInLayout?n.strokeWeight*2:0);const adjusted=child.w>available?{...child,w:available}:child;n.appendChild(render(adjusted));}return n;
}
const removed=[],mutated=[];const update=__UPDATE__;
for(const s of screens){
 const name='V2 · '+s.id+' · '+s.slug+' · Proposed';const existing=page.children.find(n=>n.name===name);if(existing&&!update)throw new Error('Screen exists; inspect before retry '+s.slug);
 const replacement=render(s.tree);let root=replacement;
 if(existing){root=existing;for(const child of [...root.children]){removed.push(child.id,...child.findAll?.(()=>true).map(n=>n.id)||[]);child.remove();}root.fills=replacement.fills;for(const child of [...replacement.children])root.appendChild(child);removed.push(replacement.id);replacement.remove();mutated.push(root.id);}
 root.name=name;page.appendChild(root);const index=Number(s.id)-1;root.x=40+(index%3)*1020;root.y=680+Math.floor(index/3)*630;root.placeholder=false;
 const footer=root.children.find(n=>n.name==='Commit rail');
 frames.push({id:root.id,screen:s.id,slug:s.slug,name:root.name,w:root.width,h:root.height,textCount:root.findAllWithCriteria({types:['TEXT']}).length,instanceCount:root.findAllWithCriteria({types:['INSTANCE']}).length,footerY:footer.y,footerBottom:footer.y+footer.height});
}
return {pageId:page.id,frames,createdNodeIds:created.filter(id=>!removed.includes(id)),mutatedNodeIds:mutated,removedNodeIds:removed,editable:true};
