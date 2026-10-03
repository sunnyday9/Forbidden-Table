/* Review text and accessible labels only. Language never reaches the game. */
const isChinese=document.documentElement.lang==='zh-CN';
// Labels may change language; semantic control values must stay stable.
for(const option of document.querySelectorAll('option'))if(!option.hasAttribute('value'))option.value=option.textContent;
window.FT_T=text=>isChinese?(window.FT_ZH[text]??text):text;
window.FT_COMMAND_LABEL=text=>isChinese?(Object.entries(window.FT_ZH).find(([en,zh])=>zh===text)?.[0]??text):text;
window.FT_TILE_LABEL=(suit,rank,instance)=>{
 const names={E:'East',S:'South',WEST:'West',N:'North',R:'Red dragon',G:'Green dragon',W:'White dragon'};
 const nums='一二三四五六七八九';
 const face=isChinese?(suit==='HON'?window.FT_T(names[rank]):nums[Number(rank)-1]+{BAM:'条',DOT:'筒',CHR:'万'}[suit]):suit==='HON'?names[rank]:{BAM:'Bamboo',DOT:'Dots',CHR:'Characters'}[suit]+' '+rank;
 return face+(instance?(isChinese?'，':', ')+instance:'');
};
window.FT_MESSAGE=(kind,value)=>{
 if(isChinese)return {selection:'评审选择：'+value+'。未执行游戏操作。',tile:'查看牌：'+value+'。实例选择仅为示例。',mode:value+'模式：仍保留相同的按序记录。',playing:'正在播放：'+value+'。仅为示例；未执行操作或改变状态。',final:'可读的最终状态：'+value+'动效样例。未执行游戏操作。'}[kind];
 return {selection:'Review selection: '+value+'. No game action was executed.',tile:'Tile inspected: '+value+'. Instance selection is illustrative.',mode:value+' review: the same ordered receipt remains visible.',playing:'Playing '+value+' · illustration only; no command or state change.',final:'Final readable state · '+value+' animation study. No game action executed.'}[kind];
};
const language=document.getElementById('language');
if(language){language.value=isChinese?'zh_CN':'en';language.addEventListener('change',()=>{
 const dest=language.value==='zh_CN'?'gallery-zh_CN.html':'gallery.html';
 const query=new URLSearchParams({mode:document.getElementById('mode').value,reduced:String(document.getElementById('reduced').checked),ambient:String(document.getElementById('ambient').checked),specimen:document.getElementById('specimen').value});
 location.href=dest+'?'+query+location.hash;
});}
const params=new URLSearchParams(location.search);
for(const id of ['mode','specimen'])if(params.has(id))document.getElementById(id).value=params.get(id);
for(const id of ['reduced','ambient'])if(params.has(id))document.getElementById(id).checked=params.get(id)==='true';
if(isChinese){
 const copy={
 'Forbidden Table · The haunted table':'禁忌牌桌 · 幽灯牌局',
 'PROPOSED V2.2 · Approval pending':'中英双语提案 V2.2 · 尚待批准',
 'Figma V2':'Figma 英文版', 'Art direction / motion rules':'美术方向 / 动效规范',
 'Chinese tile catalog':'标准中国麻将牌面', 'Native animation clip':'Figma 动画片段',
 'Compare V1':'对比 V1', 'Layout':'布局', 'Presentation':'反馈速度',
 'Expanded text · 125%':'扩展文本 · 125%', 'Expanded text · 150%':'扩展文本 · 150%',
 'Motion study':'动效样例', 'Replay animation':'重播动画', 'Stop':'停止',
 'Reduced motion':'减少动态效果', 'Lantern glow':'灯笼光晕',
 'Choose a motion study and Replay. All game values are illustrative.':'选择动效样例并重播。游戏数值均为示例。',
 'Design prototype only. Keyboard focus and local inspection work here; game commands, saved state and controller routing are not implemented. Art is a new cosmetic proposal. Esc stops cosmetic playback.':'仅为设计原型：可使用键盘焦点与本地查看；尚未实现游戏操作、存档或手柄路径。美术为新的外观提案。Esc 停止演示动效。',
 'Static PNG':'静态 PNG', 'Editable Figma frame':'可编辑 Figma 画面',
 'Ordered receipt · persists in every mode':'按序记录 · 所有反馈模式均保留',
 'Complete Hand settled. → Boss enters phase 2. → Victory!':'完整和牌已结算。→ 首领进入第二阶段。→ 胜利！',
 'Language':'语言', 'Language settings mockup':'语言设置样例', 'Chinese Figma':'Figma 中文版',
 };
 const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
 let n;while(n=walker.nextNode()){const text=n.nodeValue.trim();if(copy[text])n.nodeValue=n.nodeValue.replace(text,copy[text]);else if(window.FT_ZH[text])n.nodeValue=n.nodeValue.replace(text,window.FT_ZH[text]);}
 for(const [id,label] of [['screen-list','完整旅程设计样例']])document.getElementById(id)?.setAttribute('aria-label',label);
}
