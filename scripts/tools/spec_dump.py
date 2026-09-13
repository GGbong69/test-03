# docs/기획서_동전표.csv 를 다시 뽑는다.
#   python scripts/tools/spec_dump.py "C:/path/하이톤_김건의_기획서.pptx"
import sys, io, csv
# 윈도 기본이 cp949 라 한글 한 줄에 죽는다. 표를 못 뽑은 게 아니라 찍다 죽는다.
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
from pptx import Presentation
src = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\sunyi\Downloads\하이톤_김건의_기획서.pptx'
p = Presentation(src)

def tables(si):
    out = []
    def walk(shs):
        for sh in shs:
            if sh.shape_type == 6:
                walk(sh.shapes); continue
            if getattr(sh, 'has_table', False) and sh.has_table:
                out.append([[c.text.strip().replace('\n', ' ') for c in r.cells]
                            for r in sh.table.rows])
    walk(p.slides[si - 1].shapes)
    return out

rows = []
for si in range(22, 27):          # 이름 | 효과 | 가격 | 희귀도
    for t in tables(si):
        for r in t[1:]:
            if r[0]:
                rows.append([str(si), r[0], r[1], r[2].replace('G', '').strip(), r[3]])
for t in tables(27):              # 이름 | 효과 | 해금 조건 | 희귀도
    for r in t[1:]:
        if r[0]:
            rows.append(['27', r[0], r[1], '', r[3]])

out = io.StringIO()
w = csv.writer(out, lineterminator='\n')
w.writerow(['slide', 'name', 'eff', 'cost', 'rarity'])
w.writerows(rows)
io.open('docs/기획서_동전표.csv', 'w', encoding='utf-8-sig', newline='').write(out.getvalue())
print('docs/기획서_동전표.csv — %d행' % len(rows))
