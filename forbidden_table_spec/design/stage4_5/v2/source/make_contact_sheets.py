"""Compose review indexes from captured mockup PNGs (requires Pillow)."""
import json,sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ZH=len(sys.argv)>1 and sys.argv[1]=='zh_CN'
if ZH: ROOT=ROOT/'bilingual'
manifest = json.loads((ROOT / ('source/screens.zh_CN.json' if ZH else 'screen_manifest.json')).read_text(encoding='utf-8'))
font = ImageFont.truetype(str(ROOT/'fonts/NotoSansSC-Regular.otf') if ZH else str(ROOT.parent / 'source/fonts/NotoSans-Regular.ttf'), 16)
heading = ImageFont.truetype(str(ROOT/'fonts/NotoSerifSC-Regular.otf') if ZH else str(ROOT.parent / 'source/fonts/NotoSerif-Regular.ttf'), 24)

def sheet(entries, name, columns, cell_width):
    gap, top, caption = 16, 72, 40
    cell_height = round(cell_width * 540 / 960)
    rows = (len(entries) + columns - 1) // columns
    canvas = Image.new('RGB', (columns*(cell_width+gap)+gap,
                       top+rows*(cell_height+caption+gap)+gap), '#101D1B')
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), '禁忌牌桌 · Stage 4.5 · V2.2 · 中文设计' if ZH else 'Forbidden Table · Stage 4.5 · V2.1 · Chinese tile faces', fill='#F3EBD8', font=heading)
    draw.text((gap, 43), '中文提案 · 尚待批准 · 浏览器设计图，非游戏截图' if ZH else 'PROPOSED v2.1 · Approval pending · Browser mockups, not game captures', fill='#D8B875', font=font)
    for i, entry in enumerate(entries):
        x, y = gap+(i % columns)*(cell_width+gap), top+(i // columns)*(cell_height+caption+gap)
        capture = Image.open(ROOT / 'mockups' / (entry['id']+'-'+entry['slug']+'.png')).convert('RGB')
        capture = capture.resize((cell_width, cell_height), Image.Resampling.LANCZOS)
        canvas.paste(capture, (x, y))
        label = entry['id']+' · '+entry['title']
        if len(label)>45:
            label = label[:42]+'…'
        draw.text((x, y+cell_height+6), label, fill='#BECBC3', font=font)
    canvas.save(ROOT / 'mockups' / name)

for i in range(3):
    sheet(manifest[i*12:(i+1)*12], 'contact-'+str(i+1)+'.png', 3, 384)
core = [entry for entry in manifest if entry['slug'] in
        ['character', 'map-act-1', 'battle-table', 'pattern-settlement', 'workshop-value', 'summary-victory']]
sheet(core, 'overview.png', 2, 480)
print('Created 3 contact sheets and overview.png')
