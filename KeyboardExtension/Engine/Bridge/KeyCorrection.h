#pragma once

#include <algorithm>
#include <limits>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "FuzzyToneLM.h"
#include "Syllable.h"
#include "gramambular2/reading_grid.h"

namespace DouJian {

// 鄰鍵容錯的尺（log10，跟詞庫分數同一把）。配合 SamsungTheme 的基本代價 2.5、上限 4、σ 0.28、最多 3 顆一起用模擬調的
struct CorrectionTuning {
    /// 一次重排最多試幾個替換（挑代價最低的）
    static constexpr size_t maxReplacements = 12;
    /// 沒贏但差不到這麼多：放一個在引擎猜的後面
    static constexpr double nearMargin = 1.0;
    /// 只有一個音時：代價不超過這個才列
    static constexpr double singleMaxCost = 3.5;
    static constexpr size_t singleMaxCount = 2;
    /// 只有一個音時：插在這一格起（不搶前三個）
    static constexpr size_t singleIndex = 3;
};

// 這一下也可能是想按的鍵
struct Alternative {
    BPMF symbol;
    double cost = 0;
};

// 按了一下注音鍵（或用空白鍵定成一聲）
struct KeyEvent {
    BPMF symbol;
    bool sealed = false; // 空白鍵定的一聲
    std::vector<Alternative> alternatives;
};

// 一個音的按鍵，跟格子裡的讀音（或正在打的音）一對一
struct SyllableKeys {
    std::vector<KeyEvent> keys;
    bool closed = false; // 沒打聲調、但不是被下一個符號擠收起來的（選走前段時收的）：重新斷音時不准跟後面接起來
};

struct Replacement {
    size_t syllable = 0;
    size_t key = 0;
    Alternative alternative;
};

// 換一個鍵之後的整句
struct CorrectedSentence {
    std::string value;
    std::string reading;
    double score = 0; // 還沒扣代價
    size_t syllables = 0;
};

/// 新符號接不上正在打的音 → 要另起一個音
inline bool startsNewSyllable(FuzzyToneLM &lm, const BPMF &current, const BPMF &incoming) {
    if (stage(incoming) <= stage(current)) return true;
    if (current.isEmpty() || incoming.hasToneMarker()) return false;
    // 段落雖然排得上，但接上後變成不存在的音（如 ㄉㄧ＋ㄦ）→ 也另起新音，打「第二」不用打聲調
    BPMF joined = current;
    joined += incoming;
    return !lm.isSyllableStart(joined);
}

class KeyCorrection {
public:
    explicit KeyCorrection(FuzzyToneLM &lm) : lm_(lm) {}

    /// 所有按鍵的替換，挑代價最低的幾個
    static std::vector<Replacement> cheapest(const std::vector<SyllableKeys> &syllables) {
        std::vector<Replacement> out;
        for (size_t s = 0; s < syllables.size(); s++) {
            for (size_t k = 0; k < syllables[s].keys.size(); k++) {
                for (const auto &a : syllables[s].keys[k].alternatives) out.push_back({s, k, a});
            }
        }
        std::stable_sort(out.begin(), out.end(), [](const Replacement &a, const Replacement &b) {
            return a.alternative.cost < b.alternative.cost;
        });
        if (out.size() > CorrectionTuning::maxReplacements) out.resize(CorrectionTuning::maxReplacements);
        return out;
    }

    /// 換掉一個鍵，照打字時同一套規則重新斷音。typed 是照打的讀音（跟 syllables 一對一）。
    /// 換了之後有音不成立（只有聲調）回傳空的
    std::optional<std::vector<std::string>> resegment(
        const std::vector<SyllableKeys> &syllables, const std::vector<std::string> &typed, const Replacement &change
    ) {
        // 換掉的鍵可能接到前一個音上，所以從前一個音開始重打；更前面的不受影響
        size_t start = change.syllable > 0 ? change.syllable - 1 : 0;
        std::vector<std::string> out(typed.begin(), typed.begin() + static_cast<std::ptrdiff_t>(start));
        BPMF buffer;
        auto flush = [&](const std::string &mark) {
            if (!buffer.isEmpty()) out.push_back(buffer.composedString() + mark);
            buffer.clear();
        };
        for (size_t s = start; s < syllables.size(); s++) {
            const auto &keys = syllables[s].keys;
            for (size_t k = 0; k < keys.size(); k++) {
                if (keys[k].sealed) {
                    if (buffer.isEmpty()) return std::nullopt;
                    flush(kToneOneMark);
                    continue;
                }
                bool changed = s == change.syllable && k == change.key;
                BPMF symbol = changed ? change.alternative.symbol : keys[k].symbol;
                if (startsNewSyllable(lm_, buffer, symbol)) flush("");
                if (buffer.isEmpty() && k == 0 && s > change.syllable) {
                    // 從這裡起又跟照打的一樣了
                    out.insert(out.end(), typed.begin() + static_cast<std::ptrdiff_t>(s), typed.end());
                    return out;
                }
                if (buffer.isEmpty() && symbol.hasToneMarker()) return std::nullopt;
                buffer += symbol;
                if (symbol.hasToneMarker()) flush("");
            }
            if (syllables[s].closed) flush("");
        }
        flush("");
        return out;
    }

    /// 整句最佳走法：每個讀音只拿最高分的詞，不用簡拼（最後一個音只打聲母除外）。走不通回傳空的
    std::optional<CorrectedSentence> best(
        const std::vector<std::string> &syllables, const std::vector<std::string> &typed
    ) {
        const size_t n = syllables.size();
        if (n == 0) return std::nullopt;
        size_t head = 0;
        while (head < n && head < typed.size() && syllables[head] == typed[head]) head++;
        size_t tail = 0;
        while (tail < n - head && tail < typed.size() - head
               && syllables[n - 1 - tail] == typed[typed.size() - 1 - tail]) tail++;
        const size_t touchedEnd = n - tail; // [head, touchedEnd) 是跟照打的不一樣的音
        const bool completable = isConsonantOnly(syllables.back());

        std::vector<Step> steps(n + 1);
        steps[0].score = 0;
        for (size_t i = 0; i < n; i++) {
            if (steps[i].score == kUnreachable) continue;
            std::string joined;
            const LightEntry *parent = nullptr;
            const size_t limit = std::min(n, i + Formosa::Gramambular2::ReadingGrid::kMaximumSpanLength);
            for (size_t j = i + 1; j <= limit; j++) {
                if (j > i + 1) joined += "-";
                joined += syllables[j - 1];
                const bool touched = i < touchedEnd && j > head;
                const LightEntry &entry = lm_.light(parent, joined, syllables[j - 1]);
                relax(steps, i, j, touched ? entry.touched : entry.best);
                if (j == n && completable) {
                    const LightEntry &full = lm_.lightCompletion(parent, joined, syllables[j - 1]);
                    relax(steps, i, j, touched ? full.touched : full.best);
                }
                if (entry.next.empty()) break;
                parent = &entry;
            }
        }
        if (steps[n].score == kUnreachable) return std::nullopt;
        return trace(steps, n);
    }

private:
    static constexpr double kUnreachable = -std::numeric_limits<double>::infinity();

    struct Step {
        double score = kUnreachable;
        size_t from = 0;
        const LightWord *word = nullptr;
    };

    static void relax(std::vector<Step> &steps, size_t from, size_t to, const LightWord &word) {
        if (!word.found) return;
        double score = steps[from].score + word.score;
        if (score > steps[to].score) steps[to] = {score, from, &word};
    }

    static CorrectedSentence trace(const std::vector<Step> &steps, size_t n) {
        CorrectedSentence out;
        out.score = steps[n].score;
        out.syllables = n;
        for (size_t at = n; at > 0; at = steps[at].from) {
            const LightWord &w = *steps[at].word;
            out.value = w.value + out.value;
            out.reading = out.reading.empty() ? w.reading : w.reading + "-" + out.reading;
        }
        return out;
    }

    FuzzyToneLM &lm_;
};

} // namespace DouJian
