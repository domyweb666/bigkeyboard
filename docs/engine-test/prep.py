import io, os, re, random, glob, sys
here = os.path.dirname(os.path.abspath(__file__))
# 1. 從原本的 .mm 抽出 C++ 核心，編成 baseline
src = open(os.path.join(here, 'orig.mm'), encoding='utf-8').read()
core = src[src.index('namespace {'):src.index('@implementation')]
head = '''#pragma once
#include <algorithm>
#include <map>
#include <memory>
#include <string>
#include <string_view>
#include <utility>
#include <vector>
#include "Mandarin/Mandarin.h"
#include "MemoryMappedFile.h"
#include "ParselessLM.h"
#include "ParselessPhraseDB.h"
#include "gramambular2/reading_grid.h"
namespace orig {
typedef size_t NSUInteger;
using Formosa::Gramambular2::ReadingGrid;
using Formosa::Mandarin::BopomofoKeyboardLayout;
using Formosa::Mandarin::BopomofoReadingBuffer;
using Formosa::Mandarin::BPMF;
using Unigram = Formosa::Gramambular2::LanguageModel::Unigram;
'''
open(os.path.join(here, 'orig_core.h'), 'w', encoding='utf-8', newline='\n').write(head + core + '\n} // namespace orig\n')

# 2. 句子語料（照 sim2.py）
NB = set('ㄅㄉˇˋㄓˊ˙ㄚㄞㄢㄦㄆㄊㄍㄐㄔㄗㄧㄛㄟㄣㄇㄋㄎㄑㄕㄘㄨㄜㄠㄤㄈㄌㄏㄒㄖㄙㄩㄝㄡㄥ')
lm = []
for line in open(os.path.join(here, 'data.txt'), encoding='utf-8'):
    p = line.rstrip('\n').split(' ')
    if len(p) != 3 or p[0].startswith('_') or line[0] == '#': continue
    if any(c not in NB and c != '-' for c in p[0]): continue
    lm.append((p[0], p[1], float(p[2])))
byword = {}
for rd, w, s in lm:
    if len(rd.split('-')) == len(w) and s > byword.get(w, ('', -99))[1]: byword[w] = (rd, s)
def seg(t):
    b = [(0, None)] + [(-1e9, None)] * len(t)
    for i in range(len(t)):
        for j in range(i + 1, min(len(t), i + 6) + 1):
            w = t[i:j]
            if w in byword and b[i][0] + byword[w][1] > b[j][0]: b[j] = (b[i][0] + byword[w][1], i)
    if b[-1][0] < -1e8: return None
    out = []; j = len(t)
    while j:
        i = b[j][1]; out.append(byword[t[i:j]][0]); j = i
    return '-'.join(reversed(out))
random.seed(7)
txt = ''
for f in sorted(glob.glob('E:/豆鍵/.vibe/*.md') + glob.glob('E:/豆鍵/.aso/*.md')):
    txt += open(f, encoding='utf-8').read() + '\n'
cl = sorted({c for c in re.findall('[一-鿿]+', txt) if 4 <= len(c) <= 10}); random.shuffle(cl)
sents = [(c, seg(c)) for c in cl]; sents = [x for x in sents if x[1]]
with open(os.path.join(here, 'sents.txt'), 'w', encoding='utf-8', newline='\n') as f:
    for c, r in sents[:500]: f.write(c + ' ' + r + '\n')
# 另一批沒用來調參數的
with open(os.path.join(here, 'sents2.txt'), 'w', encoding='utf-8', newline='\n') as f:
    for c, r in sents[500:1500]: f.write(c + ' ' + r + '\n')
# 3. 照詞頻抽 2～4 字詞（不重複抽樣的前 N 名＋加權）
for n in (1, 2, 3, 4):
    best = {}
    for rd, w, s in lm:
        if len(w) == n == len(rd.split('-')) and s > best.get(w, ('', -99))[1] : best[w] = (rd, s)
    ranked = sorted(best.items(), key=lambda x: -x[1][1])
    top = ranked[:1500]
    with open(os.path.join(here, 'top%d.txt' % n), 'w', encoding='utf-8', newline='\n') as f:
        for w, (rd, s) in top: f.write(w + ' ' + rd + '\n')
    pool = [(w, rd, s) for w, (rd, s) in ranked if s > -6]
    pick = random.choices(pool, [10 ** s for _, _, s in pool], k=1500)
    with open(os.path.join(here, 'words%d.txt' % n), 'w', encoding='utf-8', newline='\n') as f:
        for w, rd, s in pick: f.write(w + ' ' + rd + '\n')
# 4. 名字（詞庫沒有的）：姓＋兩個常用字
sur = '陳林黃張李王吳劉蔡楊許鄭謝洪郭邱曾廖賴徐周葉蘇莊呂江何蕭羅高'
chars = [(w, rd, s) for w, (rd, s) in sorted(((w, v) for w, v in byword.items() if len(w) == 1), key=lambda x: -x[1][1])[:1500]]
with open(os.path.join(here, 'names.txt'), 'w', encoding='utf-8', newline='\n') as f:
    for _ in range(1000):
        s = random.choice(sur); a = random.choice(chars[150:]); b = random.choice(chars[150:])
        f.write(s + a[0] + b[0] + ' ' + '-'.join([byword[s][0], a[1], b[1]]) + '\n')
print(len(sents))
