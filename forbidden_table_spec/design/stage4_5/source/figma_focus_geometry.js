// Idempotent refinement of inspected existing shared components; not game code.
const ledger=__LEDGER__;
const page=await figma.getNodeByIdAsync(ledger.pages.library);
await figma.setCurrentPageAsync(page);
const sets=[await figma.getNodeByIdAsync(ledger.buttonSet),await figma.getNodeByIdAsync(ledger.tileSet)];
const components=sets.flatMap(s=>s.children).filter(c=>/State=(focused|selectedFocused)$/.test(c.name));
for(const c of components)for(const t of c.findAllWithCriteria({types:['TEXT']}))for(const s of t.getStyledTextSegments(['fontName']))await figma.loadFontAsync(s.fontName);
const variable=await figma.variables.getVariableByIdAsync(ledger.variables.focus);
const created=[],mutated=[];
for(const c of components){
 let ring=c.children.find(n=>n.type==='RECTANGLE'&&n.name==='Focus perimeter · independent of selection');
 if(!ring){ring=figma.createRectangle();ring.name='Focus perimeter · independent of selection';c.appendChild(ring);created.push(ring.id);}else mutated.push(ring.id);
 ring.layoutPositioning='ABSOLUTE';ring.fills=[];
 ring.strokes=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:160/255,g:231/255,b:239/255}},'color',variable)];
 ring.strokeWeight=3;ring.strokeAlign='OUTSIDE';ring.cornerRadius=c.cornerRadius+2;
 ring.resize(c.width+4,c.height+4);ring.x=-2;ring.y=-2;
 ring.constraints={horizontal:'STRETCH',vertical:'STRETCH'};
 c.effects=[];c.clipsContent=false;mutated.push(c.id);
}
return {createdNodeIds:created,mutatedNodeIds:mutated};
