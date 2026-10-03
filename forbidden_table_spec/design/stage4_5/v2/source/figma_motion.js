await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('2020:2'));
const root=await figma.getNodeByIdAsync('2027:532'), tile=await figma.getNodeByIdAsync('2027:574'), row=tile.parent;
for(const text of tile.findAll(n=>n.type==='TEXT')) for(const s of text.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(s.fontName);
const index=row.children.indexOf(tile);const wrapper=figma.createFrame();wrapper.name='Animated tile wrapper · final face stays legible';wrapper.resize(42,64);wrapper.fills=[];wrapper.layoutMode='NONE';wrapper.clipsContent=false;row.insertChild(index,wrapper);wrapper.appendChild(tile);tile.x=0;tile.y=0;tile.manualKeyframeTracks={};tile.opacity=1;
const ease={type:'EASE_OUT'};
function track(name,start,end){wrapper.applyManualKeyframeTrack({type:'PROPERTY',name},{baseValue:{type:'FLOAT',value:end},keyframes:[{timelinePosition:0,value:{type:'FLOAT',value:start},easing:ease},{timelinePosition:.6,value:{type:'FLOAT',value:end},easing:ease}]});}
track('TRANSLATION_X',90,0);track('TRANSLATION_Y',-96,0);track('ROTATION',-8,0);
root.setTimelineDuration(root.timelines[0].id,2);
return {createdNodeIds:[wrapper.id],mutatedNodeIds:[root.id,row.id,tile.id],motion:{rootId:root.id,tileId:tile.id,wrapperId:wrapper.id,timelines:root.timelines,tracks:wrapper.manualKeyframeTracks,animations:wrapper.animations},finalTile:{visible:tile.visible,opacity:tile.opacity,w:tile.width,h:tile.height}};
