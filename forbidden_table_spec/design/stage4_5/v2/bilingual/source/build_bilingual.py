"""Generate review-only bilingual fixtures; never modifies runtime resources."""
import copy
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'bilingual'
SOURCE = HERE / 'source'
screens = json.loads((ROOT / 'source/screens.json').read_text())
strings = json.loads((SOURCE / 'strings.json').read_text())
strings.update({
    'Intro\nCurrent':'入口\n当前位置', 'Battle\nLeft':'战斗\n左侧',
    'Battle\nRight':'战斗\n右侧', 'Shop':'商店', 'Workshop':'工坊',
    'Event\nLeft':'事件\n左侧', 'Event\nRight':'事件\n右侧',
    'Battle\nMid':'战斗\n中段', 'Elite':'精英', 'Boss':'首领',
    'Current · Reachable: left / right · Later nodes unavailable':'当前位置 · 可达：左 / 右 · 后续节点暂不可用',
    'RELIC':'遗物', 'RULE BREAKER':'破规能力', 'Relic':'遗物', 'Rule Breaker':'破规能力',
    'East':'东风', 'South':'南风', 'West':'西风', 'North':'北风',
    'Red dragon':'红中', 'Green dragon':'发财', 'White dragon':'白板',
    'Language':'语言', 'English · selected':'English · 已选择',
    '简体中文 · selected':'简体中文 · 已选择',
    'Language changes display text only. Your Run stays at the same decision.':'语言仅改变显示文字。当前旅程停留在同一决策点。',
    'Keyboard / controller: choose a language, then confirm.':'键盘 / 手柄：选择语言后确认。',
    'Apply language':'应用语言', 'Language settings':'语言设置',
    'Normal':'标准', 'Tile arrives':'摸牌入手',
    'Hand → Boss phase → Victory':'完整和牌 → 首领阶段 → 胜利',
    'Reward reveal':'奖励展示', 'Workshop before / after':'工坊修改前 / 后',
    'Complete Hand settled.':'完整和牌已结算。', 'Boss enters phase 2.':'首领进入第二阶段。',
    'Victory!':'胜利！', 'HAND SETTLED':'完整和牌已结算', 'BOSS · PHASE 2':'首领 · 第二阶段',
    'VICTORY':'胜利',
    'Choose a motion study and Replay. All game values are illustrative.':'选择动效样例并重播。游戏数值均为示例。',
    'Stopped at readable static state.':'已停止，保留可读的静态状态。',
    'Expanded localized detail sheet specimen':'本地化长文本详情样例',
})
def walk(node, screen=None):
    if node.get('text'):
        value=node['text']
        if value not in strings: raise ValueError('Missing translation: '+value)
        node['text']=strings[value]
        if screen=='character' and value in ('Reserve','Sequence'):
            node['text']={'Reserve':'藏牌师','Sequence':'顺子师'}[value]
    if node.get('kind'): node['kind']=strings[node['kind']]
    if node.get('instanceLabel'):
        node['instanceLabel']=node['instanceLabel'].replace('copy ','副本 ')
    for child in node.get('children',[]): walk(child,screen)

translated=copy.deepcopy(screens)
for screen in translated:
    screen['title']=strings[screen['title']]
    screen['notes']='中文设计提案，尚待批准。牌面、实例选择、操作可用性及游戏规则与英文样例一致。插画与动效仅用于展示；本页面不执行游戏操作。'
    screen['locale']='zh_CN'; screen['version']='Proposed v2.2 bilingual'
    walk(screen['tree'],screen['slug'])

language_en=copy.deepcopy(next(s for s in screens if s['slug']=='settings'))
language_en.update(id='L1',slug='language',title='Language settings',notes='Proposed language preference; no Run mutation. English and Simplified Chinese are MVP targets.')
language_en['tree']['children'][0]['children'][0]['children'][1]['text']='Language settings'
panel=language_en['tree']['children'][2]['children'][1]
panel['name']='Language settings'
def text(value,size=16):return {'type':'text','text':value,'size':size,'w':432,'color':'text'}
def button(value,state='default'):return {'type':'button','text':value,'w':432,'h':44,'state':state}
panel['children']=[text('Language',18),button('English · selected','selected'),button('简体中文','focused'),text('Language changes display text only. Your Run stays at the same decision.'),text('Keyboard / controller: choose a language, then confirm.',14)]
language_en['tree']['children'][-1]['children'][-1]['text']='Apply language'
language_en['tree']['children'][2]['children'][0]['children'][2]['state']='default'
language_zh=copy.deepcopy(language_en)
language_zh.update(id='L2',slug='language-zh',title='语言设置',notes='语言为本机显示偏好；确认后保留同一决策点、所选牌实例与焦点目标。取消保留原语言。')
strings.update({'简体中文':'简体中文'})
walk(language_zh['tree'])
buttons=language_zh['tree']['children'][2]['children'][1]['children']
buttons[1].update(text='English',state='focused');buttons[2].update(text='简体中文 · 已选择',state='selected')

ledger=json.loads((SOURCE / 'figma_ledger.json').read_text()) if (SOURCE/'figma_ledger.json').exists() else {'fileKey':'xXzt7gEelGQh37Ak51ogGa','frames':[]}
(SOURCE/'screens.zh_CN.json').write_text(json.dumps(translated,ensure_ascii=False,indent=2)+'\n')
(SOURCE/'language-screens.json').write_text(json.dumps([language_en,language_zh],ensure_ascii=False,indent=2)+'\n')
(SOURCE/'review_data.zh_CN.js').write_text('window.FT_V2.screens='+json.dumps(translated,ensure_ascii=False)+';\nwindow.FT_V2.ledger='+json.dumps(ledger)+';\n')
(SOURCE/'language_data.js').write_text('window.FT_V2.screens='+json.dumps([language_en,language_zh],ensure_ascii=False)+';\nwindow.FT_V2.ledger='+json.dumps(ledger)+';\n')
(SOURCE/'strings.json').write_text(json.dumps(strings,ensure_ascii=False,indent=2)+'\n')
(SOURCE/'strings.js').write_text('window.FT_ZH='+json.dumps(strings,ensure_ascii=False)+';\n')
with (SOURCE/'design-copy.en_zh_CN.csv').open('w',newline='') as f:
    writer=csv.writer(f);writer.writerow(['design_key','en','zh_CN'])
    for index,(en,zh) in enumerate(strings.items(),1):writer.writerow([f'DESIGN_{index:04}',en,zh])
runtime=list(csv.DictReader((ROOT.parents[3]/'localization/en.csv').open()))
with (SOURCE/'runtime-key-inventory.csv').open('w',newline='') as f:
    writer=csv.writer(f);writer.writerow(['existing_key','en','matching_design_zh_CN','status'])
    for row in runtime:
        en=row['en'];zh=strings.get(en,'')
        # A lexical match is a suggestion, not contextual or grammatical validation.
        writer.writerow([row['keys'],en,zh,'context review required' if zh else 'translation required after approval'])
report={'source':'localization/en.csv','source_sha256':hashlib.sha256((ROOT.parents[3]/'localization/en.csv').read_bytes()).hexdigest(),'runtime_keys':len(runtime),'design_strings':len(strings),'chinese_screens':len(translated),'language_specimens':2,'lexical_matches':sum(r['en'] in strings for r in runtime),'runtime_translation_complete':False,'runtime_modified':False}
(SOURCE/'coverage.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
