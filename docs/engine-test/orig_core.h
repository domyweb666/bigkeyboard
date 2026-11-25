#pragma once
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

// 空白鍵定成一聲的音，在格子裡的讀音後面接這個記號（詞庫裡一聲沒有記號，查詢前要拿掉）。
// 不帶記號、沒聲調的音是「哪一聲都可以」；帶記號的只查一聲。
const std::string kToneOneMark = "ˉ";

bool isSealedToneOne(const std::string &syllable) {
    return syllable.size() > kToneOneMark.size()
        && syllable.compare(syllable.size() - kToneOneMark.size(), kToneOneMark.size(), kToneOneMark) == 0;
}

std::string withoutToneOneMark(const std::string &reading) {
    std::string out;
    for (size_t pos = 0;;) {
        size_t hit = reading.find(kToneOneMark, pos);
        out += reading.substr(pos, hit == std::string::npos ? std::string::npos : hit - pos);
        if (hit == std::string::npos) return out;
        pos = hit + kToneOneMark.size();
    }
}

// 這個音是不是使用者自己打完的（打了聲調，或用空白鍵定成一聲）
bool hasToneMark(const std::string &syllable) {
    return isSealedToneOne(syllable) || BPMF::FromComposedString(syllable).hasToneMarker();
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
// 快打時每按一鍵都要查很多次：①一個音一個音展開，詞庫裡沒有這個開頭的就不往下展開（不再 5×5×5… 全試）；
// ②查過的讀音記起來，同一段注音不重查。
// 最後一個音只打了聲母（如「ㄧㄥ ㄍ」的 ㄍ）：當成還沒打完，補成詞庫裡以它開頭的音（應該），分數扣一點，
// 讓完整打出來的音排在補出來的前面。
class FuzzyToneLM : public Formosa::Gramambular2::LanguageModel {
public:
    FuzzyToneLM(std::shared_ptr<McBopomofo::ParselessLM> lm, const char *dataPath) : lm_(std::move(lm)) {
        // 另開一份唯讀映射查「有沒有這個開頭」（mmap 跟 LM 共用同一份檔案頁面，不多佔記憶體）
        if (file_.open(dataPath)) {
            db_ = std::make_unique<McBopomofo::ParselessPhraseDB>(file_.data(), file_.length());
        }
    }

    void setUserPhrases(std::map<std::string, std::vector<Unigram>> phrases) {
        user_ = std::move(phrases);
        cache_.clear();
    }

    std::vector<Unigram> getUnigrams(const std::string &reading) override {
        auto hit = cache_.find(reading);
        if (hit != cache_.end()) return hit->second;
        std::vector<Unigram> out;
        for (const auto &[variant, completed] : expand(reading)) {
            double penalty = completed ? kCompletionPenalty : 0;
            auto user = user_.find(variant);
            if (user != user_.end()) {
                for (const auto &u : user->second) out.emplace_back(u.value(), u.score() + penalty, variant);
            }
            for (const auto &u : lm_->getUnigrams(variant)) {
                out.emplace_back(u.value(), u.score() + penalty, variant);
            }
        }
        std::stable_sort(out.begin(), out.end(), [](const Unigram &a, const Unigram &b) {
            return a.score() > b.score();
        });
        if (cache_.size() > 4000) cache_.clear(); // 打很久之後清掉，記憶體不會一直長
        cache_[reading] = out;
        return out;
    }

    bool hasUnigrams(const std::string &reading) override { return !getUnigrams(reading).empty(); }

    /// 詞庫裡有沒有以這個音（可能還沒打完）開頭的讀音。「ㄉㄧㄦ」沒有 → 打 ㄦ 時要另起一個音
    bool isSyllableStart(const std::string &syllable) const {
        return !db_ || db_->findFirstMatchingLine(syllable) != nullptr;
    }

private:
    static constexpr double kCompletionPenalty = -1.0;

    // 只打了聲母、還沒打韻母和聲調
    static bool isConsonantOnly(const std::string &syllable) {
        BPMF s = BPMF::FromComposedString(syllable);
        return s.hasConsonant() && !s.hasMiddleVowel() && !s.hasVowel() && !s.hasToneMarker();
    }

    // 詞庫和使用者字典裡以 key 開頭、音節數跟 key 一樣的讀音（key 的最後一個音是只打了聲母的）
    std::vector<std::string> completions(const std::string &key) const {
        auto dashes = std::count(key.begin(), key.end(), '-');
        std::vector<std::string> out;
        auto keep = [&](std::string_view full) {
            if (std::count(full.begin(), full.end(), '-') != dashes) return;
            std::string k(full);
            if (std::find(out.begin(), out.end(), k) == out.end()) out.push_back(std::move(k));
        };
        if (db_) {
            for (const auto &row : db_->findRows(key)) keep(row.substr(0, row.find(' ')));
        }
        for (auto it = user_.lower_bound(key); it != user_.end() && it->first.compare(0, key.size(), key) == 0; ++it) {
            keep(it->first);
        }
        return out;
    }

    static bool hasTone(const std::string &syllable) {
        for (const char *t : {"ˊ", "ˇ", "ˋ", "˙"}) {
            if (syllable.find(t) != std::string::npos) return true;
        }
        return false;
    }

    // 詞庫或使用者字典裡有沒有以 prefix 開頭的讀音（prefix 結尾帶 "-" 表示後面還有音、帶 " " 表示到此為止）
    bool hasPrefix(const std::string &prefix) const {
        if (db_ && db_->findFirstMatchingLine(prefix) != nullptr) return true;
        std::string bare = prefix.substr(0, prefix.size() - 1);
        char tail = prefix.back();
        for (auto it = user_.lower_bound(bare); it != user_.end(); ++it) {
            const std::string &key = it->first;
            if (key.compare(0, bare.size(), bare) != 0) break;
            if (tail == ' ' ? key.size() == bare.size() : (key.size() > bare.size() && key[bare.size()] == '-')) {
                return true;
            }
        }
        return false;
    }

    // "ㄅㄨ-ㄧㄠˋ" → 詞庫裡真的有的那幾種，如 {"ㄅㄨˊ-ㄧㄠˋ"}（輕聲 ˙ 在詞庫裡寫在後面）。
    // 一個音一個音接上去，接上後詞庫裡沒有這個開頭的就丟掉。
    // 最後一個音只打了聲母時，另外補上以它開頭的完整讀音（second = true 表示是補出來的）
    std::vector<std::pair<std::string, bool>> expand(const std::string &reading) const {
        std::vector<std::string> syllables;
        size_t start = 0;
        for (size_t i = 0; i <= reading.size(); i++) {
            if (i == reading.size() || reading[i] == '-') {
                syllables.push_back(reading.substr(start, i - start));
                start = i + 1;
            }
        }
        std::vector<std::string> results{""};
        std::vector<std::string> completed;
        for (size_t idx = 0; idx < syllables.size() && !results.empty(); idx++) {
            const auto &syl = syllables[idx];
            std::vector<std::string> variants;
            if (isSealedToneOne(syl)) {
                variants = {syl.substr(0, syl.size() - kToneOneMark.size())};
            } else if (hasTone(syl)) {
                variants = {syl};
            } else {
                variants = {syl, syl + "ˊ", syl + "ˇ", syl + "ˋ", syl + "˙"};
            }
            bool last = idx + 1 == syllables.size();
            std::vector<std::string> next;
            if (last && isConsonantOnly(syl) && !isSealedToneOne(syl)) {
                for (const auto &prefix : results) {
                    for (auto &full : completions(idx == 0 ? syl : prefix + "-" + syl)) {
                        completed.push_back(std::move(full));
                    }
                }
            }
            for (const auto &prefix : results) {
                for (const auto &v : variants) {
                    std::string candidate = idx == 0 ? v : prefix + "-" + v;
                    if (hasPrefix(candidate + (last ? " " : "-"))) next.push_back(std::move(candidate));
                }
            }
            results.swap(next);
        }
        std::vector<std::pair<std::string, bool>> out;
        for (auto &r : results) out.emplace_back(std::move(r), false);
        for (auto &c : completed) {
            if (std::find(results.begin(), results.end(), c) == results.end()) out.emplace_back(std::move(c), true);
        }
        return out;
    }

    std::shared_ptr<McBopomofo::ParselessLM> lm_;
    McBopomofo::MemoryMappedFile file_;
    std::unique_ptr<McBopomofo::ParselessPhraseDB> db_;
    std::map<std::string, std::vector<Unigram>> user_; // 使用者字典：讀音 → 詞
    std::map<std::string, std::vector<Unigram>> cache_; // 查過的讀音 → 結果
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


} // namespace orig
