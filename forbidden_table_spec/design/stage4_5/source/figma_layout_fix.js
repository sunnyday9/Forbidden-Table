// Pending targeted Figma correction. Embed actual ledger and choose one page per call.
const ledger=__LEDGER__, pageId=__PAGE__;
const page=await figma.getNodeByIdAsync(pageId);await figma.setCurrentPageAsync(page);
for(const f of [{family:'Noto Sans',style:'Regular'},{family:'Noto Sans',style:'SemiBold'},{family:'Noto Serif',style:'Regular'},{family:'Noto Sans SC',style:'Regular'}])await figma.loadFontAsync(f);
const changed=[];
for(const record of ledger.frames){const root=await figma.getNodeByIdAsync(record.id);if(root.parent.id!==pageId)continue;
 const main=root.children[2];if(main.type==='FRAME'&&main.layoutMode==='HORIZONTAL'){main.resize(928,348);main.primaryAxisSizingMode='FIXED';main.counterAxisSizingMode='FIXED';changed.push(main.id);}
 for(const row of root.findAll(n=>n.type==='FRAME'&&n.name==='row')){if(row.height<=1.01){row.counterAxisSizingMode='AUTO';row.primaryAxisSizingMode='FIXED';changed.push(row.id);}}
 for(const i of root.findAllWithCriteria({types:['INSTANCE']})){if(i.width<=50)continue;const label=i.children.find(n=>n.type==='TEXT');if(!label)continue;label.textAutoResize='HEIGHT';label.layoutSizingHorizontal='FILL';label.textAlignHorizontal='CENTER';i.counterAxisSizingMode='AUTO';i.minHeight=44;changed.push(i.id,label.id);}
}
return {mutatedNodeIds:changed,createdNodeIds:[],pageId,requiresVisualRecheck:true};
