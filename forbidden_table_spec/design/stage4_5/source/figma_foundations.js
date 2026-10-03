// Design-only Figma construction; no Godot resource is emitted.
// Self-contained equivalents of the Figma skill's scoped-token helpers.
function hexToFigmaColor(hex){return {r:parseInt(hex.slice(1,3),16)/255,g:parseInt(hex.slice(3,5),16)/255,b:parseInt(hex.slice(5,7),16)/255,a:1};}
async function createVariableCollection(name,names){
 const collection=figma.variables.createVariableCollection(name),modeIds={};
 collection.renameMode(collection.defaultModeId,names[0]);modeIds[names[0]]=collection.defaultModeId;
 for(const name of names.slice(1))modeIds[name]=collection.addMode(name);
 return {collection,modeIds};
}
async function createSemanticTokens(collection,modeIds,definitions){
 const variables={};
 for(const d of definitions){
  const v=figma.variables.createVariable(d.name,collection,d.type);v.scopes=d.scopes;
  for(const [mode,value] of Object.entries(d.values))v.setValueForMode(modeIds[mode],typeof value==='string'&&value.startsWith('#')?hexToFigmaColor(value):value);
  if(d.codeSyntax?.WEB)v.setVariableCodeSyntax('WEB',d.codeSyntax.WEB);
  variables[d.name]=v;
 }
 return {variables};
}
const created = [], mutated = [];
const track = n => { created.push(n.id); return n; };
const page = figma.currentPage;
page.name = '01 · Components and visual rules'; mutated.push(page.id);
const fonts = [{family:'Noto Sans',style:'Regular'},{family:'Noto Sans',style:'SemiBold'},{family:'Noto Serif',style:'Regular'},{family:'Noto Sans SC',style:'Regular'}];
for (const font of fonts) await figma.loadFontAsync(font);
const palette = __PALETTE__;
const local = await figma.variables.getLocalVariableCollectionsAsync();
if(local.some(c=>c.name==='FT Primitives')) throw new Error('Foundations already exist; inspect ledger before retry.');
const primitives = await createVariableCollection('FT Primitives',['Value']);
const semantics = await createVariableCollection('FT Semantic',['Value']);
const componentTokens = await createVariableCollection('FT Components',['Value']);
const vars = {};
for (const [name,hex] of Object.entries(palette)) {
 const p = (await createSemanticTokens(primitives.collection,primitives.modeIds,[{name:'color/'+name,type:'COLOR',values:{Value:hex},scopes:[],codeSyntax:{WEB:'var(--ft-'+name+')'}}])).variables['color/'+name];
 const scopes=['text','muted','error','success','ink'].includes(name)?['TEXT_FILL']:['FRAME_FILL','SHAPE_FILL','STROKE_COLOR'];
 vars[name]=(await createSemanticTokens(semantics.collection,semantics.modeIds,[{name:'color/'+name,type:'COLOR',values:{Value:{type:'VARIABLE_ALIAS',id:p.id}},scopes,codeSyntax:{WEB:'var(--ft-'+name+')'}}])).variables['color/'+name];
}
for (const [name,alias,scopes] of [['button/fill','raised',['FRAME_FILL']],['button/primary','brass',['FRAME_FILL']],['tile/face','text',['FRAME_FILL']],['tile/ink','ink',['TEXT_FILL']],['panel/fill','panel',['FRAME_FILL']],['focus/ring','focus',['STROKE_COLOR']]]) {
 const v=(await createSemanticTokens(componentTokens.collection,componentTokens.modeIds,[{name,type:'COLOR',values:{Value:{type:'VARIABLE_ALIAS',id:vars[alias].id}},scopes,codeSyntax:{WEB:'var(--ft-'+name.replaceAll('/','-')+')'}}])).variables[name]; vars[name]=v;
}
for(const val of [4,8,12,16,24,32]) {
 vars['space'+val]=(await createSemanticTokens(semantics.collection,semantics.modeIds,[{name:'spacing/'+val,type:'FLOAT',values:{Value:val},scopes:['GAP'],codeSyntax:{WEB:'var(--ft-space-'+val+')'}}])).variables['spacing/'+val];
}
const styles={};
for(const [name,size,line,font] of [['Body',16,24,fonts[0]],['Label',16,22,fonts[1]],['Secondary',14,20,fonts[0]],['Section',18,24,fonts[1]],['Title',26,34,fonts[2]],['Outcome',32,40,fonts[2]],['TileRank',24,28,fonts[1]],['TileSuit',12,16,fonts[0]]]) {
 const s=figma.createTextStyle();s.name='FT/'+name;s.fontName=font;s.fontSize=size;s.lineHeight={unit:'PIXELS',value:line}; styles[name]=s.id;
}
const paint=name=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:(()=>{const {a,...rgb}=hexToFigmaColor(palette[name.split('/')[0]]||palette.raised);return rgb;})()},'color',vars[name]);
const txt=(label,size=16,color='text',font=fonts[0])=>{const n=track(figma.createText());n.fontName=font;n.fontSize=size;n.lineHeight={unit:'PIXELS',value:size===12?16:size===24?28:22};n.characters=label;n.fills=[paint(color)];return n;};
const buttonStates=['default','primary','focused','selected','selectedFocused','disabled','pressed'];
const buttons=[];
for(const [i,state] of buttonStates.entries()) {
 const c=track(figma.createComponent());c.name='State='+state;c.resize(208,44);c.layoutMode='HORIZONTAL';c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';c.primaryAxisAlignItems='CENTER';c.counterAxisAlignItems='CENTER';c.paddingLeft=12;c.paddingRight=12;c.paddingTop=8;c.paddingBottom=8;c.cornerRadius=6;
 c.fills=[paint(state==='primary'?'button/primary':state==='pressed'?'panel':'button/fill')];c.strokes=[paint(state==='selected'||state==='selectedFocused'?'brass':state==='focused'?'focus/ring':'edge')];c.strokeWeight=state.includes('Focused')||state==='focused'?3:1;
 const t=txt(state==='disabled'?'Unavailable · reason':'Action',16,state==='primary'?'ink':state==='disabled'?'muted':'text',fonts[1]);c.appendChild(t);t.textStyleId=styles.Label;t.textAutoResize='HEIGHT';t.layoutSizingHorizontal='FILL';t.textAlignHorizontal='CENTER';c.counterAxisSizingMode='AUTO';c.minHeight=44;
 const prop=c.addComponentProperty('Label','TEXT',t.characters);t.componentPropertyReferences={characters:prop};
 c.setBoundVariable('paddingLeft',vars.space12);c.setBoundVariable('paddingRight',vars.space12);buttons.push(c);
}
const buttonSet=track(figma.combineAsVariants(buttons,page));buttonSet.name='FT ActionButton';buttonSet.description='Existing command action. Focus and selection are independent; unavailable reason stays readable. 44 px minimum height. Never commit on focus.';
buttonSet.x=40;buttonSet.y=680;buttonSet.resize(3*224+40,3*60+40);buttons.forEach((c,i)=>{c.x=20+(i%3)*224;c.y=20+Math.floor(i/3)*60;});
const tileVariants=[];
for(const suit of ['BAM','DOT','CHR','HON']) for(const state of ['default','focused','selected','selectedFocused']) {
 const c=track(figma.createComponent());c.name='Suit='+suit+', State='+state;c.resize(42,64);c.layoutMode='VERTICAL';c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';c.primaryAxisAlignItems='CENTER';c.counterAxisAlignItems='CENTER';c.itemSpacing=0;c.cornerRadius=4;c.fills=[paint('tile/face')];c.strokes=[paint(state==='focused'||state==='selectedFocused'?'focus':'selected'===state?'brass':'edge')];c.strokeWeight=state==='default'?1:3;
 const rank=txt('2',24,'ink',fonts[1]);rank.name='Rank';const glyph=txt({BAM:'| |',DOT:'●',CHR:'萬',HON:'東'}[suit],18,'ink',suit==='CHR'||suit==='HON'?fonts[3]:fonts[0]);glyph.name='Glyph';const label=txt(suit,12,'ink');label.name='Suit';c.appendChild(rank);c.appendChild(glyph);c.appendChild(label);glyph.lineHeight={unit:'PIXELS',value:20};
 for(const t of [rank,glyph,label]) { const prop=c.addComponentProperty(t.name,'TEXT',t.characters);t.componentPropertyReferences={characters:prop}; }
 tileVariants.push(c);
}
const tileSet=track(figma.combineAsVariants(tileVariants,page));tileSet.name='FT TileFace';tileSet.description='Identity-first editable tile. Rank/suit/honor are redundant with glyph. Exact TileInstance and contextual rule details belong in inspector. Selected+focused may show both marks.';tileSet.x=800;tileSet.y=680;tileSet.resize(4*66+40,4*88+40);tileVariants.forEach((c,i)=>{c.x=20+(i%4)*66;c.y=20+Math.floor(i/4)*88;});
const pages={library:page.id};for(const name of ['02 · Full Run journey','03 · Interaction states and stress cases']) {const p=track(figma.createPage());p.name=name;pages[name.startsWith('02')?'journey':'states']=p.id;}
const cover=track(figma.createAutoLayout('VERTICAL'));cover.name='Visual direction and review status';cover.resize(1120,540);cover.primaryAxisSizingMode='FIXED';cover.counterAxisSizingMode='FIXED';cover.x=40;cover.y=40;cover.paddingTop=24;cover.paddingLeft=24;cover.paddingRight=24;cover.paddingBottom=24;cover.itemSpacing=16;cover.fills=[paint('table')];
for(const [label,size,color,font] of [['FORBIDDEN TABLE · STAGE 4.5',14,'muted',fonts[1]],['A supernatural table, clearly read.',32,'text',fonts[2]],['PROPOSED v1 · Awaiting maintainer approval',18,'brass',fonts[1]],['Readability → State clarity → Tile recognition → Feedback → Decoration',18,'text',fonts[0]],['Dark felt. Ivory faces. Brass selection. Cyan focus. No gameplay or Domain changes.',16,'muted',fonts[0]],['Noto Sans for rules and controls · Noto Serif for titles · Noto Sans SC for tile glyphs',16,'muted',fonts[0]]]) {const t=txt(label,size,color,font);cover.appendChild(t);}
const swatches=track(figma.createAutoLayout('HORIZONTAL'));swatches.name='Palette';swatches.resize(1040,84);swatches.itemSpacing=8;swatches.fills=[];cover.appendChild(swatches);
for(const name of ['panel','raised','text','brass','focus','error','success']) {const sw=track(figma.createAutoLayout('VERTICAL'));sw.resize(136,72);sw.paddingLeft=8;sw.paddingTop=8;sw.fills=[paint(name)];swatches.appendChild(sw);sw.appendChild(txt(name,14,['text','brass','focus','error','success'].includes(name)?'ink':'text'));}
const ledger={fileKey:figma.fileKey,pages,variables:Object.fromEntries(Object.entries(vars).map(([k,v])=>[k,v.id])),collections:[primitives.collection.id,semantics.collection.id,componentTokens.collection.id],styles,buttonSet:buttonSet.id,tileSet:tileSet.id,cover:cover.id};
return {ledger,createdNodeIds:created,mutatedNodeIds:mutated,counts:{variables:(await figma.variables.getLocalVariablesAsync()).length,buttonVariants:buttons.length,tileVariants:tileVariants.length,textStyles:Object.keys(styles).length},bounds:{cover:{w:cover.width,h:cover.height}}};
