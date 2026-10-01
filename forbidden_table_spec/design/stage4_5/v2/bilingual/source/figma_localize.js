// Clone English frames, retaining component instances, tile hashes and state cues.
const roots=await Promise.all(__ROOTS__.map(f=>figma.getNodeByIdAsync(f.id)));
if(roots.some(n=>!n))throw new Error('Missing English source frame');
const dict=__STRINGS__,page=await figma.getNodeByIdAsync(__PAGE__);
await figma.setCurrentPageAsync(page);
const pairs=__ROOTS__;
if(pairs.some(f=>page.children.some(n=>n.name==='V2.2 · zh_CN · '+f.screen+' · '+f.slug)))throw new Error('Chinese frame exists; inspect before retry');
const fonts=new Map();
for(const root of roots)for(const t of root.findAllWithCriteria({types:['TEXT']}))for(const s of t.getStyledTextSegments(['fontName']))fonts.set(JSON.stringify(s.fontName),s.fontName);
for(const f of [{family:'Noto Sans SC',style:'Regular'},{family:'Noto Sans SC',style:'Medium'},{family:'Noto Serif SC',style:'Regular'}])fonts.set(JSON.stringify(f),f);
await Promise.all([...fonts.values()].map(f=>figma.loadFontAsync(f)));
const created=[],mutated=[],frames=[],untranslated=[];
for(let i=0;i<roots.length;i++){
 const original=roots[i],meta=pairs[i],clone=original.clone();page.appendChild(clone);
 clone.name='V2.2 · zh_CN · '+meta.screen+' · '+meta.slug;const index=Number(meta.screen)-1;clone.x=40+(index%3)*1020;clone.y=680+Math.floor(index/3)*630;
 created.push(clone.id,...clone.query('*').map(n=>n.id));
 for(const t of clone.findAllWithCriteria({types:['TEXT']})){
  if(!t.visible)continue;
  const old=t.characters;let zh=dict[old];
  if(meta.slug==='character'&&old==='Reserve')zh='藏牌师';
  if(meta.slug==='character'&&old==='Sequence')zh='顺子师';
  if(zh===undefined){untranslated.push({root:clone.id,node:t.id,text:old});continue;}
  const font=t.getStyledTextSegments(['fontName'])[0]?.fontName;
  t.fontName={family:font?.family.includes('Serif')?'Noto Serif SC':'Noto Sans SC',style:font?.family.includes('Serif')?'Regular':font?.style==='Regular'?'Regular':'Medium'};
  t.characters=zh;mutated.push(t.id);
 }
 const footer=clone.children.find(n=>n.name==='Commit rail');
 const actionOverflow=clone.findAllWithCriteria({types:['INSTANCE']}).filter(n=>n.name!=='Tile'&&!/^(BAM|DOT|CHR|HON) /.test(n.name)).flatMap(n=>n.findAllWithCriteria({types:['TEXT']}).filter(t=>t.visible&&(t.width>n.width-12||t.height>n.height-8)).map(t=>({id:t.id,text:t.characters,width:t.width,height:t.height,parentW:n.width,parentH:n.height})));
 frames.push({id:clone.id,screen:meta.screen,slug:meta.slug,name:clone.name,w:clone.width,h:clone.height,footerY:footer.y,footerBottom:footer.y+footer.height,actionOverflow,textCount:clone.findAllWithCriteria({types:['TEXT']}).filter(t=>t.visible).length});
}
return {createdNodeIds:created,mutatedNodeIds:mutated,frames,untranslated};
