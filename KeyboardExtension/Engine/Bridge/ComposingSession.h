#pragma once

#include <algorithm>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "CandidateList.h"
#include "FuzzyToneLM.h"
#include "KeyCorrection.h"
#include "Mandarin/Mandarin.h"
#include "Syllable.h"
#include "gramambular2/reading_grid.h"

namespace DouJian {

// 一次組字的全部狀態：格子（已收起來的音）、正在打的音、每個音按了哪些鍵、候選。
// 按鍵紀錄（keys_、bufferKeys_）跟格子、buffer 一對一，格子動了就跟著動。
class ComposingSession {
public:
    using Alternatives = std::vector<std::pair<std::string, double>>; // 符號、代價

    bool open(const char *dataPath) {
        lm_ = std::make_shared<FuzzyToneLM>();
        if (!lm_->open(dataPath)) return false;
        grid_ = std::make_unique<ReadingGrid>(lm_);
        return true;
    }

    // MARK: 打字

    bool feed(const std::string &symbol, const Alternatives &alternatives) {
        char key = keyForSymbol(symbol);
        if (!key) return false;
        BPMF incoming = BPMF::FromComposedString(symbol);
        if (startsNewSyllable(*lm_, buffer_.syllable(), incoming)) {
            // 接不上目前這個音 → 目前的當一聲收起來，另起新音
            pushBufferIntoGrid();
        } else if (buffer_.isEmpty()) {
            closeLastSyllable(); // 前一個音要是沒打聲調，也不是被這個符號擠收起來的
        }
        bool ok = buffer_.combineKey(key);
        bufferKeys_.push_back(makeEvent(incoming, alternatives));
        // 有聲調就是完整的一個音，直接收進格子
        if (buffer_.syllable().hasToneMarker()) pushBufferIntoGrid();
        rebuild();
        return ok;
    }

    bool canSealFirstTone() {
        if (buffer_.isEmpty() || buffer_.syllable().hasToneMarker()) return false;
        // 前面有沒打聲調的音 → 這串是不打聲調的快打，空白鍵照舊送字（定成一聲會把「我們」這種輕聲詞查壞）
        for (const auto &r : grid_->readings()) {
            if (!hasToneMark(r)) return false;
        }
        // 這個音沒有一聲的字（如 ㄦ、只打了 ㄉ）→ 空白鍵照舊送字
        return lm_->hasUnigrams(buffer_.syllable().composedString() + kToneOneMark);
    }

    void sealFirstTone() {
        if (!canSealFirstTone()) return;
        KeyEvent seal;
        seal.sealed = true;
        bufferKeys_.push_back(seal);
        insertIntoGrid(buffer_.syllable().composedString() + kToneOneMark);
        buffer_.clear();
        rebuild();
    }

    bool backspace() {
        if (!buffer_.isEmpty()) {
            buffer_.backspace();
            bufferKeys_.pop_back();
        } else if (grid_->length() > 0) {
            // 把最後一個音拿回來，再退掉它最後一個符號（空白鍵定的一聲：只退掉一聲，注音留著）
            bool sealed = isSealedToneOne(grid_->readings().back());
            takeLastBack();
            if (!sealed) buffer_.backspace();
            bufferKeys_.pop_back();
        } else {
            return false;
        }
        reopenLastReadingIfBufferEmpty();
        rebuild();
        return true;
    }

    /// 選第 index 個候選：回傳它的字，吃掉的那幾個音從格子前面拿掉
    std::string select(size_t index) {
        if (index >= list_.items.size()) return "";
        Candidate picked = list_.items[index];
        pushBufferIntoGrid();
        size_t span = std::min(picked.span, grid_->length());
        // 記下選走的讀音：有查中的帶聲調讀音就用它，否則用格子裡打的
        if (!picked.reading.empty()) {
            lastSelectedReading_ = picked.reading;
        } else {
            const auto &readings = grid_->readings();
            std::string joined;
            for (size_t i = 0; i < span && i < readings.size(); i++) {
                if (i > 0) joined += "-";
                joined += readings[i];
            }
            lastSelectedReading_ = withoutToneOneMark(joined);
        }
        grid_->setCursor(span);
        for (size_t i = 0; i < span; i++) grid_->deleteReadingBeforeCursor();
        grid_->setCursor(grid_->length());
        keys_.erase(keys_.begin(), keys_.begin() + static_cast<std::ptrdiff_t>(span));
        rebuild();
        return picked.value;
    }

    void clear() {
        buffer_.clear();
        bufferKeys_.clear();
        grid_->clear();
        keys_.clear();
        list_ = {};
    }

    void setUserPhrases(UserPhrases phrases) { lm_->setUserPhrases(std::move(phrases)); }

    void setPreferred(std::vector<std::string> words) {
        preferred_ = std::move(words);
        if (grid_->length() > 0 || !buffer_.isEmpty()) rebuild();
    }

    // MARK: 給畫面看的

    /// 音與音之間空一格，看得出斷在哪裡
    std::string composing() const {
        std::string s;
        for (const auto &r : grid_->readings()) {
            if (!s.empty()) s += " ";
            s += r;
        }
        if (!buffer_.isEmpty()) {
            if (!s.empty()) s += " ";
            s += buffer_.composedString();
        }
        return s;
    }

    int composingStage() const { return stage(buffer_.syllable()); }
    const std::vector<Candidate> &candidates() const { return list_.items; }
    size_t defaultCount() const { return list_.defaults; }
    const std::string &lastSelectedReading() const { return lastSelectedReading_; }

    // MARK: 給測試對帳用

    const std::vector<std::string> &readings() const { return grid_->readings(); }
    std::string bufferReading() const { return buffer_.composedString(); }
    const std::vector<SyllableKeys> &keys() const { return keys_; }
    const std::vector<KeyEvent> &bufferKeys() const { return bufferKeys_; }

private:
    using ReadingGrid = Formosa::Gramambular2::ReadingGrid;

    static KeyEvent makeEvent(const BPMF &symbol, const Alternatives &alternatives) {
        KeyEvent event;
        event.symbol = symbol;
        for (const auto &[text, cost] : alternatives) {
            if (!keyForSymbol(text)) continue;
            event.alternatives.push_back({BPMF::FromComposedString(text), cost});
        }
        return event;
    }

    // MARK: 格子、buffer、按鍵紀錄一起動

    /// 把 reading 收進格子，bufferKeys_ 跟著搬過去。詞庫沒有這個音：打了聲調的先換一個鄰鍵試試，
    /// 還是不行就整個丟掉（按鍵紀錄一起丟）
    void insertIntoGrid(const std::string &reading) {
        grid_->setCursor(grid_->length());
        if (grid_->insertReading(reading) || (buffer_.hasToneMarker() && insertRescued())) {
            SyllableKeys syllable;
            syllable.keys = std::move(bufferKeys_);
            keys_.push_back(std::move(syllable));
        } else {
            closeLastSyllable(); // 中間隔著丟掉的音，前一個音不會跟之後打的接起來
        }
        bufferKeys_.clear();
    }

    /// keys_ 最後一個音：沒打聲調的話，重新斷音時不准跟後面接起來
    void closeLastSyllable() {
        if (!keys_.empty() && !hasToneMark(grid_->readings()[keys_.size() - 1])) keys_.back().closed = true;
    }

    /// 打完的音不存在（ㄖㄣ˙）：不換的話整個音會消失，所以換成代價最低、存在的那個（ㄖㄣˊ）收進格子
    bool insertRescued() {
        for (const auto &r : KeyCorrection::cheapest({SyllableKeys{bufferKeys_, false}})) {
            std::vector<KeyEvent> keys = bufferKeys_;
            keys[r.key].symbol = r.alternative.symbol;
            // 換掉的是第一個鍵：可能就是它害前一個音被拆開（ㄑ ㄝˋ → ㄑㄧˋ）
            if (r.key == 0 && !keys_.empty() && !keys_.back().closed && !hasToneMark(grid_->readings().back())) {
                std::vector<KeyEvent> joined = keys_.back().keys;
                joined.insert(joined.end(), keys.begin(), keys.end());
                if (insertRescued(std::move(joined), true)) return true;
            }
            if (insertRescued(std::move(keys), false)) return true;
        }
        return false;
    }

    bool insertRescued(std::vector<KeyEvent> keys, bool joinsLast) {
        BPMF syllable;
        for (const auto &k : keys) {
            if (startsNewSyllable(*lm_, syllable, k.symbol)) return false; // 接不成一個音
            syllable += k.symbol;
        }
        if (!syllable.hasToneMarker() || stage(keys.front().symbol) == 4) return false;
        if (!lm_->hasUnigrams(syllable.composedString())) return false;
        if (joinsLast) {
            grid_->deleteReadingBeforeCursor();
            keys_.pop_back();
        } else {
            closeLastSyllable(); // 換過的鍵可能接得上前一個音，當初是分開收的
        }
        grid_->insertReading(syllable.composedString());
        bufferKeys_ = std::move(keys);
        return true;
    }

    void pushBufferIntoGrid() {
        if (buffer_.isEmpty()) return;
        insertIntoGrid(buffer_.syllable().composedString());
        buffer_.clear();
    }

    /// 格子最後一個音拿回 buffer（buffer 要是空的）
    void takeLastBack() {
        std::string last = grid_->readings().back();
        grid_->setCursor(grid_->length());
        grid_->deleteReadingBeforeCursor();
        for (const auto &ch : splitUTF8(last)) {
            char k = keyForSymbol(ch);
            if (k) buffer_.combineKey(k);
        }
        bufferKeys_ = std::move(keys_.back().keys);
        keys_.pop_back();
    }

    // 刪到正在打的那個音空了，而前一個音沒打聲調（是被下一個接不上的符號擠收起來的）→ 拿回來繼續組。
    // 刪完的樣子要跟重打剩下的符號一樣：打 ㄐ、按錯 ㄍ、刪掉 ㄍ，再打 ㄧㄝ 要接成「ㄐㄧㄝ」，不是「ㄐ ㄧㄝ」。
    // 有聲調的音是使用者自己打完的，留在格子裡。
    void reopenLastReadingIfBufferEmpty() {
        if (!buffer_.isEmpty() || grid_->length() == 0) return;
        if (hasToneMark(grid_->readings().back())) return;
        takeLastBack();
    }

    // MARK: 候選

    void rebuild() {
        list_ = {};
        bool tentative = false;
        if (!buffer_.isEmpty()) {
            grid_->setCursor(grid_->length());
            tentative = grid_->insertReading(buffer_.syllable().composedString());
        }
        if (grid_->length() == 0) return;

        auto walk = grid_->walk();
        Sentence typed = typedSentence(walk);
        // 第一個候選：整句最佳走法串起來（兩段以上才有，跟系統注音一樣一次送整句）
        if (walk.nodes.size() >= 2) list_.items.push_back({typed.value, grid_->length(), typed.reading});
        // 接著：整句的第一段（通常就是第一個詞）
        if (!walk.nodes.empty()) {
            const auto &n = walk.nodes.front();
            list_.items.push_back({n->value(), n->spanningLength(), n->currentUnigram().rawValue()});
        }
        list_.defaults = list_.items.size();
        list_.append(grid_->candidatesAt(0));
        bool promoted = list_.promote(preferred_, grid_->length());
        // 按鍵紀錄跟格子的音一對一才找修正（正在打的音收不進格子時就不找）
        if (tentative || buffer_.isEmpty()) addCorrections(typed, promoted);

        if (tentative) {
            grid_->setCursor(grid_->length());
            grid_->deleteReadingBeforeCursor();
        }
    }

    // 照打的整句
    struct Sentence {
        std::string value;
        std::string reading;
        double score = 0;
        size_t words = 0;
    };

    static Sentence typedSentence(const ReadingGrid::WalkResult &walk) {
        Sentence out;
        for (const auto &n : walk.nodes) {
            out.value += n->value();
            if (!out.reading.empty()) out.reading += "-";
            out.reading += n->currentUnigram().rawValue();
            out.score += n->score();
        }
        out.words = walk.nodes.size();
        return out;
    }

    // MARK: 鄰鍵容錯

    void addCorrections(const Sentence &typed, bool promoted) {
        std::vector<SyllableKeys> syllables = keys_;
        if (!buffer_.isEmpty()) syllables.push_back({bufferKeys_, false});
        auto replacements = KeyCorrection::cheapest(syllables);
        if (replacements.empty() || syllables.size() != grid_->length()) return;
        lm_->trimLightCache();
        if (syllables.size() == 1) {
            addSingleCorrections(syllables, replacements);
        } else {
            addSentenceCorrection(syllables, replacements, typed, promoted);
        }
    }

    /// 兩個音以上：最好的一個替換。贏了照打的就搶第一，差一點就放在引擎猜的後面
    void addSentenceCorrection(
        const std::vector<SyllableKeys> &syllables, const std::vector<Replacement> &replacements,
        const Sentence &typed, bool promoted
    ) {
        KeyCorrection correction(*lm_);
        const auto &readings = grid_->readings();
        double typedScore = typed.score;
        CorrectedSentence best;
        double bestScore = 0;
        for (const auto &r : replacements) {
            auto changed = correction.resegment(syllables, readings, r);
            if (!changed || *changed == readings) continue;
            auto sentence = correction.best(*changed, readings);
            if (!sentence) continue;
            double score = sentence->score - r.alternative.cost;
            if (sentence->value == typed.value) {
                typedScore = std::max(typedScore, score); // 換了還是同樣的字：算照打的
            } else if (best.syllables == 0 || score > bestScore) {
                best = std::move(*sentence);
                bestScore = score;
            }
        }
        if (best.syllables == 0 || bestScore <= typedScore - CorrectionTuning::nearMargin) return;
        Candidate picked{best.value, grid_->length(), best.reading, true};
        if (bestScore > typedScore && best.syllables >= 2 && !promoted) {
            list_.putFirst(std::move(picked), typed.words == 1);
        } else if (!list_.contains(best.value)) {
            list_.insert(list_.defaults, std::move(picked));
        }
    }

    /// 只有一個音：不搶第一，代價夠低的最多列兩個字在後面
    void addSingleCorrections(
        const std::vector<SyllableKeys> &syllables, const std::vector<Replacement> &replacements
    ) {
        const auto &readings = grid_->readings();
        if (omission(readings.front()) != Omission::none) return; // 才打一個聲母，還看不出要打什麼
        KeyCorrection correction(*lm_);
        std::vector<std::pair<double, Candidate>> found;
        for (const auto &r : replacements) {
            if (r.alternative.cost > CorrectionTuning::singleMaxCost) break; // 照代價低到高排
            auto changed = correction.resegment(syllables, readings, r);
            if (!changed || changed->size() != 1 || isConsonantOnly(changed->front())) continue;
            auto word = correction.best(*changed, readings);
            if (!word || list_.contains(word->value)) continue;
            found.emplace_back(word->score - r.alternative.cost, Candidate{word->value, 1, word->reading, true});
        }
        std::stable_sort(found.begin(), found.end(), [](const auto &a, const auto &b) { return a.first > b.first; });
        // 接續紀錄提到前面的字也算引擎猜的，插在那些後面，defaults 才對得上
        size_t at = std::min(std::max(CorrectionTuning::singleIndex, list_.defaults), list_.items.size());
        const size_t end = at + CorrectionTuning::singleMaxCount;
        for (auto &item : found) {
            if (at == end) break;
            if (list_.contains(item.second.value)) continue; // 兩個替換修正出同一個字
            list_.insert(at, std::move(item.second));
            at++;
        }
    }

    std::shared_ptr<FuzzyToneLM> lm_;
    std::unique_ptr<ReadingGrid> grid_; // 已收起來的音（可多個）
    std::vector<SyllableKeys> keys_; // 格子裡每個音按了哪些鍵
    // 正在打、還沒收進格子的那一個音
    Formosa::Mandarin::BopomofoReadingBuffer buffer_{Formosa::Mandarin::BopomofoKeyboardLayout::StandardLayout()};
    std::vector<KeyEvent> bufferKeys_;
    CandidateList list_;
    std::vector<std::string> preferred_; // 使用者常接在游標前那段字後面的字詞
    std::string lastSelectedReading_;
};

} // namespace DouJian
