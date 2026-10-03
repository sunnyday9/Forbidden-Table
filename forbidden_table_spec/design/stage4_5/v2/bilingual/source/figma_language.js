const page=await figma.getNodeByIdAsync('2043:2');await figma.setCurrentPageAsync(page);
const sources=await Promise.all(['2024:991','2044:1370','2024:1014','2024:1004','2024:1006','2024:1019','2024:1020'].map(id=>figma.getNodeByIdAsync(id)));
const fonts=new Map();for(const root of sources){const ts=root.type==='TEXT'?[root]:root.findAllWithCriteria({types:['TEXT']});for(const t of ts)for(const s of t.getStyledTextSegments(['fontName']))fonts.set(JSON.stringify(s.fontName),s.fontName);}
for(const f of [{family:'Noto Sans SC',style:'Regular'},{family:'Noto Sans SC',style:'Medium'},{family:'Noto Serif SC',style:'Regular'}])fonts.set(JSON.stringify(f),f);
await Promise.all([...fonts.values()].map(f=>figma.loadFontAsync(f)));
if(page.children.some(n=>n.name==='V2.2 · L1 · Language settings'))throw new Error('Language specimens exist; inspect');
const made=[],changed=[],removed=[],frames=[];
function record(n){made.push(n.id,...(n.children?n.query('*').map(c=>c.id):[]));return n;}
function setCopy(n,value,weight='Regular'){n.fontName={family:'Noto Sans SC',style:weight};n.characters=value;changed.push(n.id);}
for(let i=0;i<2;i++){
 const root=record(sources[i].clone());page.appendChild(root);root.name='V2.2 · L'+(i+1)+' · Language settings';root.x=40+i*1020;root.y=8320;
 const head=root.children[0].children[0].children[1];head.fontName={family:'Noto Serif SC',style:'Regular'};head.characters=i?'设置 · 语言':'Settings · Language';changed.push(head.id);
 const speeds=root.children[2].children[0].children.filter(n=>n.type==='INSTANCE');
 speeds[1].swapComponent(speeds[2].mainComponent);
 setCopy(speeds[1].findAllWithCriteria({types:['TEXT']})[0],i?'快速':'Fast','Medium');changed.push(speeds[1].id);
 const panel=root.children[2].children[1];panel.name='Language settings';changed.push(panel.id);
 for(const child of [...panel.children])if(child.type!=='VECTOR'){removed.push(child.id);child.remove();}
 const title=record(sources[2].clone());panel.appendChild(title);setCopy(title,i?'语言':'Language','Medium');
 const english=record(sources[i?4:3].clone());panel.appendChild(english);english.resize(430,44);setCopy(english.findAllWithCriteria({types:['TEXT']})[0],i?'English':'English · selected','Medium');
 const chinese=record(sources[i?3:4].clone());panel.appendChild(chinese);chinese.resize(430,44);setCopy(chinese.findAllWithCriteria({types:['TEXT']})[0],i?'简体中文 · 已选择':'简体中文','Medium');
 const body=record(sources[5].clone());panel.appendChild(body);setCopy(body,i?'语言仅改变显示文字。当前旅程停留在同一决策点。':'Language changes display text only. Your Run stays at the same decision.');
 const note=record(sources[6].clone());panel.appendChild(note);setCopy(note,i?'键盘 / 手柄：选择语言后确认。':'Keyboard / controller: choose a language, then confirm.');
 const commit=root.children[3].children[2].findAllWithCriteria({types:['TEXT']})[0];setCopy(commit,i?'应用语言':'Apply language','Medium');
 frames.push({id:root.id,screen:'L'+(i+1),slug:i?'language-zh':'language',w:root.width,h:root.height,footerBottom:root.children[3].y+root.children[3].height});
}
const banner=record(figma.createAutoLayout('VERTICAL',{name:'Bilingual MVP · Design review gate',itemSpacing:16,paddingLeft:28,paddingRight:28,paddingTop:24,paddingBottom:24}));page.appendChild(banner);banner.resize(1960,280);banner.primaryAxisSizingMode='FIXED';banner.counterAxisSizingMode='FIXED';banner.x=40;banner.y=40;banner.fills=[{type:'SOLID',color:{r:.055,g:.098,b:.086}}];
for(const [value,size] of [['禁忌牌桌 / Forbidden Table · 中文与英文',36],['PROPOSED V2.2 · 尚待批准 / Approval pending',24],['36 个中文画面 + 英文对照 + 双语设置样例。麻将牌面、规则、实例身份与反馈顺序保持一致。',20],['MVP target: English + 简体中文. Runtime localization and game UI await explicit design approval. Stage 5 remains 1.0 Release Candidate.',20]]){
 const t=record(figma.createText());banner.appendChild(t);t.fontName={family:size===36?'Noto Serif SC':'Noto Sans SC',style:'Regular'};t.fontSize=size;t.lineHeight={unit:'PIXELS',value:size===36?48:30};t.fills=[{type:'SOLID',color:{r:1,g:.945,b:.835}}];t.characters=value;t.resize(1900,t.height);t.textAutoResize='HEIGHT';
}
return {createdNodeIds:made,mutatedNodeIds:changed,removedNodeIds:removed,frames,banner:banner.id};
