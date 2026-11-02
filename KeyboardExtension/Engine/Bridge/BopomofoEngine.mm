#import "BopomofoEngine.h"

#include <algorithm>
#include <map>
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
using Unigram = Formosa::Gramambular2::LanguageModel::Unigram;

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
// 使用者字典的詞也在這裡併進來：分數比詞庫高，排在同讀音的最前面。
// 每個結果的 rawValue 記下實際查中的讀音（帶聲調），選字後自動學詞要用。
class FuzzyToneLM : public Formosa::Gramambular2::LanguageModel {
public:
    explicit FuzzyToneLM(std::shared_ptr<McBopomofo::ParselessLM> lm) : lm_(std::move(lm)) {}

    void setUserPhrases(std::map<std::string, std::vector<Unigram>> phrases) { user_ = std::move(phrases); }

    std::vector<Unigram> getUnigrams(const std::string &reading) override {
        std::vector<Unigram> out;
        for (const auto &variant : expand(reading)) {
            auto user = user_.find(variant);
            if (user != user_.end()) {
                for (const auto &u : user->second) out.emplace_back(u.value(), u.score(), variant);
            }
            for (const auto &u : lm_->getUnigrams(variant)) out.emplace_back(u.value(), u.score(), variant);
        }
        std::stable_sort(out.begin(), out.end(), [](const Unigram &a, const Unigram &b) {
            return a.score() > b.score();
        });
        return out;
    }

    bool hasUnigrams(const std::string &reading) override {
        for (const auto &variant : expand(reading)) {
            if (user_.count(variant) > 0 || lm_->hasUnigrams(variant)) return true;
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

    // "ㄅㄨ-ㄧㄠˋ" → {"ㄅㄨ-ㄧㄠˋ","ㄅㄨˊ-ㄧㄠˋ","ㄅㄨˇ-ㄧㄠˋ","ㄅㄨˋ-ㄧㄠˋ","ㄅㄨ˙-ㄧㄠˋ"}（詞庫的輕聲寫在後面）
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
                variants = {syl, syl + "ˊ", syl + "ˇ", syl + "ˋ", syl + "˙"};
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
    std::map<std::string, std::vector<Unigram>> user_; // 使用者字典：讀音 → 詞
};

// 候選字快取：字、佔幾個音、實際查中的讀音（帶聲調，可能為空）
struct CachedCandidate {
    std::string value;
    size_t span;
    std::string reading;
};

// 依使用者的接續紀錄調整候選順序：吃掉全部音（span == total）的提到最前面、算引擎猜的；
// 只吃前段的排在原本引擎猜的後面。defaults 跟著改成新的「引擎猜的」個數。
void promotePreferred(std::vector<CachedCandidate> &cache, NSUInteger &defaults,
                      const std::vector<std::string> &preferred, size_t total) {
    std::vector<bool> taken(cache.size(), false);
    std::vector<CachedCandidate> front;
    std::vector<CachedCandidate> middle;
    for (const auto &word : preferred) {
        for (size_t i = 0; i < cache.size(); i++) {
            if (taken[i] || cache[i].value != word) continue;
            taken[i] = true;
            (cache[i].span == total ? front : middle).push_back(cache[i]);
            break;
        }
    }
    if (front.empty() && middle.empty()) return;
    std::vector<CachedCandidate> out = front;
    size_t keptDefaults = 0;
    for (size_t i = 0; i < defaults && i < cache.size(); i++) {
        if (!taken[i]) {
            out.push_back(cache[i]);
            keptDefaults++;
        }
    }
    out.insert(out.end(), middle.begin(), middle.end());
    for (size_t i = defaults; i < cache.size(); i++) {
        if (!taken[i]) out.push_back(cache[i]);
    }
    defaults = front.size() + keptDefaults;
    cache.swap(out);
}

} // namespace

@implementation BopomofoEngine {
    std::shared_ptr<McBopomofo::ParselessLM> _lm;
    std::shared_ptr<FuzzyToneLM> _toneLM;
    std::unique_ptr<BopomofoReadingBuffer> _buffer; // 正在打、還沒收進格子的那一個音
    std::unique_ptr<ReadingGrid> _grid; // 已收起來的音（可多個）
    std::vector<CachedCandidate> _candidateCache;
    std::unique_ptr<McBopomofo::AssociatedPhrasesV2> _associated;
    std::string _lastSelectedReading;
    NSUInteger _defaultCandidateCount;
    std::vector<std::string> _preferred; // 使用者常接在游標前那段字後面的字詞
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
    _toneLM = std::make_shared<FuzzyToneLM>(_lm);
    _grid = std::make_unique<ReadingGrid>(_toneLM);
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
    _defaultCandidateCount = 0;
    BOOL tentative = !_buffer->isEmpty();
    if (tentative) {
        _grid->setCursor(_grid->length());
        _grid->insertReading(_buffer->syllable().composedString());
    }
    if (_grid->length() == 0) return;

    // 第一個候選：整句最佳走法串起來（兩段以上才有，跟系統注音一樣一次送整句）
    auto walk = _grid->walk();
    if (walk.nodes.size() >= 2) {
        std::string value;
        std::string reading;
        for (const auto &n : walk.nodes) {
            value += n->value();
            if (!reading.empty()) reading += "-";
            reading += n->currentUnigram().rawValue();
        }
        _candidateCache.push_back({value, _grid->length(), reading});
    }
    // 接著：整句的第一段（通常就是第一個詞）
    if (!walk.nodes.empty()) {
        const auto &n = walk.nodes.front();
        _candidateCache.push_back({n->value(), n->spanningLength(), n->currentUnigram().rawValue()});
    }
    _defaultCandidateCount = _candidateCache.size();
    // 其餘：從第 0 個音起算、所有可能的字與詞
    for (const auto &c : _grid->candidatesAt(0)) {
        size_t span = splitUTF8(c.value).size();
        bool dup = false;
        for (const auto &e : _candidateCache) if (e.value == c.value) { dup = true; break; }
        if (!dup) _candidateCache.push_back({c.value, span, c.rawValue});
    }
    promotePreferred(_candidateCache, _defaultCandidateCount, _preferred, _grid->length());

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
    // 音與音之間空一格，看得出斷在哪裡
    std::string s;
    for (const auto &r : _grid->readings()) {
        if (!s.empty()) s += " ";
        s += r;
    }
    if (!_buffer->isEmpty()) {
        if (!s.empty()) s += " ";
        s += _buffer->composedString();
    }
    return [NSString stringWithUTF8String:s.c_str()];
}

- (NSArray<NSString *> *)candidates {
    NSMutableArray<NSString *> *out = [NSMutableArray arrayWithCapacity:_candidateCache.size()];
    for (const auto &c : _candidateCache) {
        [out addObject:[NSString stringWithUTF8String:c.value.c_str()]];
    }
    return out;
}

- (NSString *)selectCandidateAtIndex:(NSUInteger)index {
    if (index >= _candidateCache.size()) return @"";
    auto picked = _candidateCache[index];
    [self pushBufferIntoGrid];
    // 把這個候選字吃掉的那幾個音從格子前面拿掉
    size_t span = std::min(picked.span, _grid->length());
    // 記下選走的讀音：有查中的帶聲調讀音就用它，否則用格子裡打的
    if (!picked.reading.empty()) {
        _lastSelectedReading = picked.reading;
    } else {
        auto readings = _grid->readings();
        std::string joined;
        for (size_t i = 0; i < span && i < readings.size(); i++) {
            if (i > 0) joined += "-";
            joined += readings[i];
        }
        _lastSelectedReading = joined;
    }
    _grid->setCursor(span);
    for (size_t i = 0; i < span; i++) _grid->deleteReadingBeforeCursor();
    _grid->setCursor(_grid->length());
    [self rebuildCandidates];
    return [NSString stringWithUTF8String:picked.value.c_str()];
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

- (void)setUserPhrasesWithReadings:(NSArray<NSString *> *)readings words:(NSArray<NSString *> *)words {
    std::map<std::string, std::vector<Unigram>> phrases;
    NSUInteger n = MIN(readings.count, words.count);
    for (NSUInteger i = 0; i < n; i++) {
        auto &list = phrases[std::string(readings[i].UTF8String)];
        // 分數 0 比詞庫裡任何詞都高（詞庫是負的對數機率）；同讀音照陣列順序微幅遞減，先後才固定
        list.emplace_back(std::string(words[i].UTF8String), -0.0001 * static_cast<double>(list.size()));
    }
    _toneLM->setUserPhrases(std::move(phrases));
}

- (void)setPreferredFollowers:(NSArray<NSString *> *)words {
    _preferred.clear();
    for (NSString *w in words) _preferred.emplace_back(w.UTF8String);
    if (_grid->length() > 0 || !_buffer->isEmpty()) [self rebuildCandidates];
}

- (NSUInteger)defaultCandidateCount {
    return _defaultCandidateCount;
}

- (NSString *)lastSelectedReading {
    return [NSString stringWithUTF8String:_lastSelectedReading.c_str()];
}

@end
