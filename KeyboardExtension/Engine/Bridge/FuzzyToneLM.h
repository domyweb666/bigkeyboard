#pragma once

#include <algorithm>
#include <iterator>
#include <map>
#include <string>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "ReadingExpander.h"
#include "gramambular2/language_model.h"

namespace DouJian {

// 容錯用的查詢：一個讀音只要最高分的那個詞
struct LightWord {
    bool found = false;
    std::string value;
    std::string reading; // 實際查中的帶聲調讀音
    double score = 0;
};

struct LightEntry {
    LightWord best;
    LightWord touched; // 這個讀音是換過鍵才對上的時候用：使用者字典的詞不給滿分，免得打對的字老是被改成自己學過的詞
    std::vector<Partial> next; // 還能往下接的開頭
};

// 沒標聲調的音節 → 五種聲調都查（手機注音可以不打聲調）。只包、不改小麥的 LM。
// 使用者字典的詞也在這裡併進來：分數比詞庫高，排在同讀音的最前面。
// 每個結果的 rawValue 記下實際查中的讀音（帶聲調），選字後自動學詞要用。
// 沒打完的音（簡拼）：最後一個音只打了聲母（「ㄧㄥ ㄍ」→ 應該）、或前面的音只打聲母／介音（「ㄒㄒ」→ 謝謝），
// 補成詞庫裡以它開頭的音，每省略一個音扣分，讓完整打出來的音排前面。
// 快打時每按一鍵都要查很多次：查過的讀音、展開到一半的開頭都記起來，同一段注音不重查。
class FuzzyToneLM : public Formosa::Gramambular2::LanguageModel {
public:
    bool open(const char *dataPath) { return expander_.open(dataPath); }

    void setUserPhrases(UserPhrases phrases) {
        expander_.setUserPhrases(std::move(phrases));
        clearUnigramCache();
        prefixes_.clear();
        prefixCount_ = 0;
        initials_.clear();
        light_.clear();
        lightCompletions_.clear();
    }

    std::vector<Unigram> getUnigrams(const std::string &reading) override { return cachedUnigrams(reading); }

    // 只看有沒有詞：直接看快取裡那份，不複製整串
    bool hasUnigrams(const std::string &reading) override { return !cachedUnigrams(reading).empty(); }

    bool isSyllableStart(const BPMF &syllable) { return expander_.isSyllableStart(syllable); }

    // MARK: 容錯用的輕量查詢（不用簡拼；另開小快取，不塞爆 cache_）

    /// 每次找修正之前叫一次。之後拿到的 LightEntry 在下一次 trim 之前都有效
    void trimLightCache() {
        if (light_.size() + lightCompletions_.size() < kMaxLightEntries) return;
        light_.clear();
        lightCompletions_.clear();
    }

    /// joined：到 syllable 為止的讀音；parent：少最後一個音的那筆（第一個音為 nullptr）
    const LightEntry &light(const LightEntry *parent, const std::string &joined, const std::string &syllable) {
        auto hit = light_.find(joined);
        if (hit != light_.end()) return hit->second;
        LightEntry entry;
        const auto &bases = parent ? parent->next : expander_.root();
        for (const auto &m : expander_.finish(bases, syllable, false, false)) consider(m, entry);
        entry.next = expander_.extend(bases, syllable, false);
        return light_.emplace(joined, std::move(entry)).first->second;
    }

    /// 最後一個音只打了聲母：補完之後最高分的詞
    const LightEntry &lightCompletion(
        const LightEntry *parent, const std::string &joined, const std::string &syllable
    ) {
        auto hit = lightCompletions_.find(joined);
        if (hit != lightCompletions_.end()) return hit->second;
        LightEntry entry;
        const auto &bases = parent ? parent->next : expander_.root();
        for (const auto &m : expander_.finish(bases, syllable, true, false)) consider(m, entry);
        return lightCompletions_.emplace(joined, std::move(entry)).first->second;
    }

private:
    static constexpr size_t kMaxCachedReadings = 4000;
    static constexpr size_t kMaxCachedUnigrams = 60000;
    static constexpr size_t kMaxCachedPartials = 20000;
    static constexpr size_t kMaxLightEntries = 3000;
    /// 補出來的多音節詞最多留幾個
    static constexpr size_t kMaxCompletions = 100;
    /// 其中看不出是不是在打簡拼的（「ㄕ ㄐㄧㄢ」的 ㄕ）最多留幾個：不要把後面的單字擠到太遠
    static constexpr size_t kMaxWeakCompletions = 8;
    /// 換過鍵、或看不出是不是在打簡拼才對上的使用者詞，當成這個分數的詞庫詞（一般的雙字、三字詞）
    static constexpr double kGuessedUserScore = -5.0;

    void clearUnigramCache() {
        cache_.clear();
        cachedUnigrams_ = 0;
    }

    /// 查過的讀音直接回快取裡那份。拿到的參照在下一次查詢之前有效（查新讀音可能清掉快取）
    const std::vector<Unigram> &cachedUnigrams(const std::string &reading) {
        auto hit = cache_.find(reading);
        if (hit != cache_.end()) return hit->second;
        auto out = lookUp(reading);
        // 打很久之後清掉，記憶體不會一直長
        if (cache_.size() > kMaxCachedReadings || cachedUnigrams_ > kMaxCachedUnigrams) clearUnigramCache();
        cachedUnigrams_ += out.size();
        out.shrink_to_fit(); // 留在快取裡很久：不要帶著 push_back 多要的空間
        auto &slot = cache_[reading];
        slot = std::move(out);
        return slot;
    }

    void consider(const Match &m, LightEntry &entry) const {
        auto take = [&](LightWord &w, const std::string &value, double score) {
            if (!w.found || score > w.score) w = LightWord{true, value, m.reading, score};
        };
        const double penalty = m.omitted.penalty();
        auto user = expander_.user().find(m.reading);
        if (user != expander_.user().end() && !user->second.empty()) {
            const auto &u = user->second.front(); // 陣列第一個分數最高
            take(entry.best, u.value(), u.score() - penalty);
            take(entry.touched, u.value(), kGuessedUserScore - penalty);
        }
        expander_.table().forEach(m.rows, [&](std::string_view word, double score) {
            std::string value(word);
            take(entry.best, value, score - penalty);
            take(entry.touched, value, score - penalty);
            return false; // 同讀音的詞分數高到低排好，第一個就是最高的
        });
    }

    std::vector<Unigram> lookUp(const std::string &reading) {
        auto syllables = splitReading(reading);
        std::vector<Unigram> out;
        std::vector<Unigram> completed;
        std::vector<Unigram> weak;
        bool word = syllables.size() > 1;
        const auto &bases = prefixes(syllables, syllables.size() - 1);
        for (const auto &m : expander_.finish(bases, syllables.back(), true, word)) {
            const double penalty = m.omitted.penalty();
            auto &list = m.omitted.weak() ? weak : m.omitted.any() ? completed : out;
            auto user = expander_.user().find(m.reading);
            if (user != expander_.user().end()) {
                for (const auto &u : user->second) {
                    // 「ㄔ ㄈㄢ」的 ㄔ 多半真的是 ㄔ：學過「炒飯」也不給滿分，不然會蓋掉「吃飯」
                    const double score = m.omitted.weak() ? std::min(u.score(), kGuessedUserScore) : u.score();
                    list.emplace_back(u.value(), score - penalty, m.reading);
                }
            }
            expander_.table().forEach(m.rows, [&](std::string_view value, double score) {
                list.emplace_back(std::string(value), score - penalty, m.reading);
                return true;
            });
        }
        keepBest(weak, kMaxWeakCompletions);
        std::move(weak.begin(), weak.end(), std::back_inserter(completed));
        if (word) keepBest(completed, kMaxCompletions);
        std::move(completed.begin(), completed.end(), std::back_inserter(out));
        sortByScore(out);
        return out;
    }

    static void sortByScore(std::vector<Unigram> &list) {
        std::stable_sort(list.begin(), list.end(), [](const Unigram &a, const Unigram &b) {
            return a.score() > b.score();
        });
    }

    // 補出來的詞：同一個字面只留最高分的，照分數最多留 limit 個
    static void keepBest(std::vector<Unigram> &list, size_t limit) {
        sortByScore(list);
        std::unordered_set<std::string> seen;
        std::vector<Unigram> kept;
        for (auto &u : list) {
            if (kept.size() >= limit) break;
            if (seen.insert(u.value()).second) kept.push_back(std::move(u));
        }
        list.swap(kept);
    }

    // 前 count 個音展開到一半的結果（記起來，打下一個鍵不重算）
    const std::vector<Partial> &prefixes(const std::vector<std::string> &syllables, size_t count) {
        if (count == 0) return expander_.root();
        if (count == 1) return initial(syllables[0]);
        std::string key = syllables[0];
        for (size_t i = 1; i < count; i++) key += "-" + syllables[i];
        auto hit = prefixes_.find(key);
        if (hit != prefixes_.end()) return hit->second;
        auto out = expander_.extend(prefixes(syllables, count - 1), syllables[count - 1], true);
        if (prefixCount_ > kMaxCachedPartials) {
            prefixes_.clear();
            prefixCount_ = 0;
        }
        prefixCount_ += out.size() + 1;
        return prefixes_.emplace(key, std::move(out)).first->second;
    }

    // 第一個音的展開（某聲母有哪些帶聲調的音）：總共沒幾種，算一次就一直留著
    const std::vector<Partial> &initial(const std::string &syllable) {
        auto hit = initials_.find(syllable);
        if (hit != initials_.end()) return hit->second;
        return initials_.emplace(syllable, expander_.extend(expander_.root(), syllable, true)).first->second;
    }

    ReadingExpander expander_;
    std::map<std::string, std::vector<Unigram>> cache_; // 查過的讀音 → 結果
    size_t cachedUnigrams_ = 0;
    std::unordered_map<std::string, std::vector<Partial>> prefixes_;
    size_t prefixCount_ = 0;
    std::unordered_map<std::string, std::vector<Partial>> initials_;
    std::unordered_map<std::string, LightEntry> light_;
    std::unordered_map<std::string, LightEntry> lightCompletions_;
};

} // namespace DouJian
