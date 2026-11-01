#import "BopomofoEngine.h"

#include <algorithm>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "AssociatedPhrasesV2.h"
#include "Mandarin/Mandarin.h"
#include "ParselessLM.h"
#include "gramambular2/reading_grid.h"

using Formosa::Gramambular2::ReadingGrid;
using Formosa::Mandarin::BopomofoKeyboardLayout;
using Formosa::Mandarin::BopomofoReadingBuffer;
using Formosa::Mandarin::BPMF;

namespace {

// 注音符號 → 它在標準鍵盤上的 ASCII 鍵
char keyForSymbol(const std::string &symbol) {
    BPMF parsed = BPMF::FromComposedString(symbol);
    if (parsed.isEmpty()) return 0;
    BPMF::Component component = 0;
    if (parsed.hasConsonant()) component = parsed.consonantComponent();
    else if (parsed.hasMiddleVowel()) component = parsed.middleVowelComponent();
    else if (parsed.hasVowel()) component = parsed.vowelComponent();
    else if (parsed.hasToneMarker()) component = parsed.toneMarkerComponent();
    return BopomofoKeyboardLayout::StandardLayout()->componentToKey(component);
}

// 一個音節「已經走到哪一段」：聲母 1 → 介音 2 → 韻母 3 → 聲調 4。新符號的段落若不比目前更後面，就該另起一音。
int stage(const BPMF &s) {
    if (s.hasToneMarker()) return 4;
    if (s.hasVowel()) return 3;
    if (s.hasMiddleVowel()) return 2;
    if (s.hasConsonant()) return 1;
    return 0;
}

// 把 UTF-8 字串拆成一個一個字元
std::vector<std::string> splitUTF8(const std::string &s) {
    std::vector<std::string> out;
    for (size_t i = 0; i < s.size();) {
        unsigned char c = s[i];
        size_t len = (c < 0x80) ? 1 : (c >> 5) == 0x6 ? 2 : (c >> 4) == 0xE ? 3 : 4;
        out.push_back(s.substr(i, len));
        i += len;
    }
    return out;
}

// 沒標聲調的音節 → 五種聲調都查（手機注音可以不打聲調）。只包、不改小麥的 LM。
class FuzzyToneLM : public Formosa::Gramambular2::LanguageModel {
public:
    explicit FuzzyToneLM(std::shared_ptr<McBopomofo::ParselessLM> lm) : lm_(std::move(lm)) {}

    std::vector<Unigram> getUnigrams(const std::string &reading) override {
        std::vector<Unigram> out;
        for (const auto &variant : expand(reading)) {
            auto part = lm_->getUnigrams(variant);
            out.insert(out.end(), part.begin(), part.end());
        }
        std::stable_sort(out.begin(), out.end(), [](const Unigram &a, const Unigram &b) {
            return a.score() > b.score();
        });
        return out;
    }

    bool hasUnigrams(const std::string &reading) override {
        for (const auto &variant : expand(reading)) {
            if (lm_->hasUnigrams(variant)) return true;
        }
        return false;
    }

private:
    static bool hasTone(const std::string &syllable) {
        for (const char *t : {"ˊ", "ˇ", "ˋ", "˙"}) {
            if (syllable.find(t) != std::string::npos) return true;
        }
        return false;
    }

    // "ㄅㄨ-ㄧㄠˋ" → {"ㄅㄨ-ㄧㄠˋ","ㄅㄨˊ-ㄧㄠˋ","ㄅㄨˇ-ㄧㄠˋ","ㄅㄨˋ-ㄧㄠˋ","˙ㄅㄨ-ㄧㄠˋ"}
    static std::vector<std::string> expand(const std::string &reading) {
        std::vector<std::string> syllables;
        size_t start = 0;
        for (size_t i = 0; i <= reading.size(); i++) {
            if (i == reading.size() || reading[i] == '-') {
                syllables.push_back(reading.substr(start, i - start));
                start = i + 1;
            }
        }
        std::vector<std::string> results{""};
        for (size_t idx = 0; idx < syllables.size(); idx++) {
            const auto &syl = syllables[idx];
            std::vector<std::string> variants;
            if (hasTone(syl)) {
                variants = {syl};
            } else {
                variants = {syl, syl + "ˊ", syl + "ˇ", syl + "ˋ", "˙" + syl};
            }
            std::vector<std::string> next;
            for (const auto &prefix : results) {
                for (const auto &v : variants) {
                    next.push_back(idx == 0 ? v : prefix + "-" + v);
                }
            }
            results.swap(next);
            if (results.size() > 700) break; // 超長的句子不展開，避免爆炸
        }
        return results;
    }

    std::shared_ptr<McBopomofo::ParselessLM> lm_;
};

} // namespace

@implementation BopomofoEngine {
    std::shared_ptr<McBopomofo::ParselessLM> _lm;
    std::unique_ptr<BopomofoReadingBuffer> _buffer; // 正在打、還沒收進格子的那一個音
    std::unique_ptr<ReadingGrid> _grid; // 已收起來的音（可多個）
    std::vector<std::pair<std::string, size_t>> _candidateCache; // (字, 佔幾個音)
    std::unique_ptr<McBopomofo::AssociatedPhrasesV2> _associated;
}

- (nullable instancetype)initWithDataPath:(NSString *)dataPath associatedPath:(nullable NSString *)associatedPath {
    self = [super init];
    if (!self) return nil;
    _lm = std::make_shared<McBopomofo::ParselessLM>();
    if (!_lm->open(dataPath.fileSystemRepresentation)) return nil;
    if (associatedPath) {
        _associated = std::make_unique<McBopomofo::AssociatedPhrasesV2>();
        if (!_associated->open(associatedPath.fileSystemRepresentation)) _associated.reset();
    }
    _buffer = std::make_unique<BopomofoReadingBuffer>(BopomofoKeyboardLayout::StandardLayout());
    _grid = std::make_unique<ReadingGrid>(std::make_shared<FuzzyToneLM>(_lm));
    return self;
}

// MARK: - 內部

- (void)pushBufferIntoGrid {
    if (_buffer->isEmpty()) return;
    _grid->setCursor(_grid->length());
    _grid->insertReading(_buffer->syllable().composedString());
    _buffer->clear();
}

- (void)rebuildCandidates {
    _candidateCache.clear();
    BOOL tentative = !_buffer->isEmpty();
    if (tentative) {
        _grid->setCursor(_grid->length());
        _grid->insertReading(_buffer->syllable().composedString());
    }
    if (_grid->length() == 0) return;

    // 第一個候選：整句最佳走法的第一個節點（通常就是整個詞）
    auto walk = _grid->walk();
    if (!walk.nodes.empty()) {
        const auto &n = walk.nodes.front();
        _candidateCache.emplace_back(n->value(), n->spanningLength());
    }
    // 其餘：從第 0 個音起算、所有可能的字與詞
    for (const auto &c : _grid->candidatesAt(0)) {
        size_t span = splitUTF8(c.value).size();
        bool dup = false;
        for (const auto &e : _candidateCache) if (e.first == c.value) { dup = true; break; }
        if (!dup) _candidateCache.emplace_back(c.value, span);
    }

    if (tentative) {
        _grid->setCursor(_grid->length());
        _grid->deleteReadingBeforeCursor();
    }
}

// MARK: - 公開接口

- (BOOL)feedSymbol:(NSString *)symbol {
    char key = keyForSymbol(symbol.UTF8String);
    if (!key) return NO;
    BPMF incoming = BPMF::FromComposedString(symbol.UTF8String);
    if (stage(incoming) <= stage(_buffer->syllable())) {
        // 接不上目前這個音 → 目前的當一聲收起來，另起新音
        [self pushBufferIntoGrid];
    }
    BOOL ok = _buffer->combineKey(key);
    if (_buffer->syllable().hasToneMarker()) {
        // 有聲調就是完整的一個音，直接收進格子
        [self pushBufferIntoGrid];
    }
    [self rebuildCandidates];
    return ok;
}

- (NSString *)composing {
    std::string s;
    for (const auto &r : _grid->readings()) s += r;
    s += _buffer->composedString();
    return [NSString stringWithUTF8String:s.c_str()];
}

- (NSArray<NSString *> *)candidates {
    NSMutableArray<NSString *> *out = [NSMutableArray arrayWithCapacity:_candidateCache.size()];
    for (const auto &c : _candidateCache) {
        [out addObject:[NSString stringWithUTF8String:c.first.c_str()]];
    }
    return out;
}

- (NSString *)selectCandidateAtIndex:(NSUInteger)index {
    if (index >= _candidateCache.size()) return @"";
    auto picked = _candidateCache[index];
    [self pushBufferIntoGrid];
    // 把這個候選字吃掉的那幾個音從格子前面拿掉
    size_t span = std::min(picked.second, _grid->length());
    _grid->setCursor(span);
    for (size_t i = 0; i < span; i++) _grid->deleteReadingBeforeCursor();
    _grid->setCursor(_grid->length());
    [self rebuildCandidates];
    return [NSString stringWithUTF8String:picked.first.c_str()];
}

- (BOOL)backspace {
    if (!_buffer->isEmpty()) {
        _buffer->backspace();
    } else if (_grid->length() > 0) {
        // 把最後一個音拿回來，再退掉它最後一個符號
        std::string last = _grid->readings().back();
        _grid->setCursor(_grid->length());
        _grid->deleteReadingBeforeCursor();
        for (const auto &ch : splitUTF8(last)) {
            char k = keyForSymbol(ch);
            if (k) _buffer->combineKey(k);
        }
        _buffer->backspace();
    } else {
        return NO;
    }
    [self rebuildCandidates];
    return YES;
}

- (void)clear {
    _buffer->clear();
    _grid->clear();
    _candidateCache.clear();
}

- (NSArray<NSString *> *)associatedPhrasesAfter:(NSString *)text {
    if (!_associated || text.length == 0) return @[];
    // 用最後一個字查（聯想詞庫的 key 是「字-讀音-字-讀音…」，只給字就是比對所有讀音）
    auto chars = splitUTF8(text.UTF8String);
    if (chars.empty()) return @[];
    const std::string &last = chars.back();
    auto phrases = _associated->findPhrases(last, {});
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (const auto &p : phrases) {
        if (p.value.size() <= last.size() || p.value.compare(0, last.size(), last) != 0) continue;
        NSString *rest = [NSString stringWithUTF8String:p.value.substr(last.size()).c_str()];
        if (rest.length == 0 || [seen containsObject:rest]) continue;
        [seen addObject:rest];
        [out addObject:rest];
        if (out.count >= 40) break;
    }
    return out;
}

@end
