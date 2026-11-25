#pragma once

#include <algorithm>
#include <map>
#include <string>
#include <utility>
#include <vector>

#include "PhraseTable.h"
#include "Syllable.h"
#include "gramambular2/language_model.h"

namespace DouJian {

using Unigram = Formosa::Gramambular2::LanguageModel::Unigram;
using UserPhrases = std::map<std::string, std::vector<Unigram>>; // 使用者字典：讀音 → 詞

// 簡拼扣的分（log10）。詞庫分數大約：常用雙字詞 -3～-4.5、常用單字 -1.5～-3
struct OmissionPenalty {
    /// 最後一個音只打了聲母（還沒打完）：從以前就是扣 1
    static constexpr double last = 1.0;
    /// 前面的音只打了聲母，而且聲母自己不成音（ㄅㄒ…）
    static constexpr double consonant = 1.0;
    /// 只打了 ㄓㄔㄕㄖㄗㄘㄙ、ㄧㄨㄩ：自己就是一個音，多半是真的在打那個音
    static constexpr double syllabic = 3.0;
    /// 同上，但同一個詞裡有不成音的聲母（「ㄨㄇ」的 ㄇ）：看得出是在打簡拼
    static constexpr double syllabicInAbbreviation = 2.0;
};

// 一個讀音裡省略了哪些音
struct Omitted {
    int consonants = 0; // 前面的音，聲母自己不成音
    int syllabics = 0; // 自己就是一個音的
    bool last = false; // 最後一個音只打了聲母
    bool lastIsPlain = false; // 而且那個聲母自己不成音

    bool any() const { return consonants > 0 || syllabics > 0 || last; }
    /// 看得出是在打簡拼，還是只是打了「ㄕ」「ㄧ」這種完整的音
    bool certain() const { return consonants > 0 || lastIsPlain; }
    bool weak() const { return syllabics > 0 && !certain(); }

    double penalty() const {
        double each = certain() ? OmissionPenalty::syllabicInAbbreviation : OmissionPenalty::syllabic;
        return consonants * OmissionPenalty::consonant + syllabics * each + (last ? OmissionPenalty::last : 0);
    }

    Omitted adding(Omission kind, bool isLast) const {
        Omitted out = *this;
        if (kind == Omission::medial || (kind == Omission::syllabicConsonant && !isLast)) {
            out.syllabics++;
        } else if (!isLast) {
            out.consonants++;
        } else {
            out.last = true;
            out.lastIsPlain = kind == Omission::consonant;
        }
        return out;
    }
};

// 展開到一半：前面幾個音已經定成帶聲調的讀音，後面還有音要接
struct Partial {
    std::string reading; // 帶聲調，如 "ㄅㄨˊ"；空的表示從頭開始
    Omitted omitted; // 到這裡為止省略掉的音
    Rows rows; // 詞庫裡以 reading + "-" 開頭的行
    bool user = false; // 使用者字典裡有沒有以 reading + "-" 開頭的

    std::string stem() const { return reading.empty() ? "" : reading + "-"; }
};

// 展開完：查得到的一個帶聲調讀音
struct Match {
    std::string reading;
    Omitted omitted;
    Rows rows; // 詞庫裡讀音剛好是 reading 的行
};

// 沒標聲調、沒打完的讀音 → 詞庫和使用者字典裡真的有的帶聲調讀音。
// 一個音一個音往下接，接上後詞庫和使用者字典都沒有這個開頭的就丟掉（不會 5×5×5… 全試）。
class ReadingExpander {
public:
    bool open(const char *path) {
        if (!table_.open(path)) return false;
        root_ = {Partial{"", Omitted{}, table_.all(), true}};
        return true;
    }

    void setUserPhrases(UserPhrases phrases) { user_ = std::move(phrases); }

    const UserPhrases &user() const { return user_; }
    const PhraseTable &table() const { return table_; }
    const std::vector<Partial> &root() const { return root_; }

    /// 詞庫裡有沒有以這個音（可能還沒打完）開頭的讀音。「ㄉㄧㄦ」沒有 → 打 ㄦ 時要另起一個音
    bool isSyllableStart(const BPMF &syllable) {
        if (starts_.empty()) starts_.assign(kSyllableCodes, kUnknown);
        char &known = starts_[rawSyllable(syllable) % kSyllableCodes];
        if (known == kUnknown) known = table_.hasPrefix(table_.all(), syllable.composedString()) ? kYes : kNo;
        return known == kYes;
    }

    /// 接一個「後面還有音」的音。omit：這個音沒打完時，要不要連省略掉的也展開（簡拼）
    std::vector<Partial> extend(const std::vector<Partial> &bases, const std::string &syllable, bool omit) const {
        std::vector<Partial> out;
        auto variants = toneVariants(syllable);
        for (const auto &base : bases) {
            for (const auto &v : variants) addPartial(base, base.stem() + v, base.omitted, out);
        }
        Omission kind = omit ? omission(syllable) : Omission::none;
        if (kind == Omission::none) return out;
        for (const auto &base : bases) {
            eachSyllable(base, syllable, [&](const std::string &full, const std::string &reading) {
                if (std::find(variants.begin(), variants.end(), full) != variants.end()) return;
                addPartial(base, reading, base.omitted.adding(kind, false), out);
            });
        }
        return out;
    }

    /// 接最後一個音。omit：沒打完時要不要補（omitMedial：只打介音的也補）
    std::vector<Match> finish(
        const std::vector<Partial> &bases, const std::string &syllable, bool omit, bool omitMedial
    ) const {
        std::vector<Match> out;
        auto variants = toneVariants(syllable);
        for (const auto &base : bases) {
            for (const auto &v : variants) addMatch(base, base.stem() + v, base.omitted, out);
        }
        Omission kind = omit ? omission(syllable) : Omission::none;
        if (kind == Omission::none || (kind == Omission::medial && !omitMedial)) return out;
        for (const auto &base : bases) {
            eachSyllable(base, syllable, [&](const std::string &full, const std::string &reading) {
                if (std::find(variants.begin(), variants.end(), full) != variants.end()) return;
                addMatch(base, reading, base.omitted.adding(kind, true), out);
            });
        }
        return out;
    }

private:
    static constexpr size_t kSyllableCodes = 1 << 14;
    static constexpr char kUnknown = 0;
    static constexpr char kYes = 1;
    static constexpr char kNo = 2;

    // 沒標聲調的音節 → 五種聲調都查（手機注音可以不打聲調；輕聲 ˙ 在詞庫裡寫在後面）
    static std::vector<std::string> toneVariants(const std::string &syllable) {
        if (isSealedToneOne(syllable)) return {syllable.substr(0, syllable.size() - kToneOneMark.size())};
        for (const char *t : {"ˊ", "ˇ", "ˋ", "˙"}) {
            if (syllable.find(t) != std::string::npos) return {syllable};
        }
        return {syllable, syllable + "ˊ", syllable + "ˇ", syllable + "ˋ", syllable + "˙"};
    }

    bool userHasPrefix(const std::string &prefix) const {
        auto it = user_.lower_bound(prefix);
        return it != user_.end() && it->first.compare(0, prefix.size(), prefix) == 0;
    }

    void addPartial(
        const Partial &base, const std::string &reading, const Omitted &omitted, std::vector<Partial> &out
    ) const {
        std::string stem = reading + "-";
        Rows rows = table_.startingWith(base.rows, stem);
        bool user = base.user && userHasPrefix(stem);
        if (!rows.empty() || user) out.push_back({reading, omitted, rows, user});
    }

    void addMatch(
        const Partial &base, const std::string &reading, const Omitted &omitted, std::vector<Match> &out
    ) const {
        Rows rows = table_.startingWith(base.rows, reading + " ");
        bool user = base.user && user_.count(reading) > 0;
        if (!rows.empty() || user) out.push_back({reading, omitted, rows});
    }

    // base 後面接得上的、以 head 開頭的音，每個看一次：visit(這個音, 到這個音為止的讀音)
    template <class F>
    void eachSyllable(const Partial &base, const std::string &head, F visit) const {
        std::string stem = base.stem();
        std::vector<std::string> seen;
        Rows rows = table_.startingWith(base.rows, stem + head);
        while (!rows.empty()) {
            const char *start = rows.begin + stem.size();
            const char *stop = std::find_if(start, rows.end, [](char c) { return c == ' ' || c == '-'; });
            std::string full(start, stop);
            visit(full, stem + full);
            // 同一個音的行連在一起（"X " 接著 "X-"），整段跳過
            Rows rest = table_.startingWith(rows, stem + full + "-");
            if (rest.empty()) rest = table_.startingWith(rows, stem + full + " ");
            rows.begin = rest.end;
            seen.push_back(std::move(full));
        }
        if (!base.user) return;
        std::string prefix = stem + head;
        for (auto it = user_.lower_bound(prefix); it != user_.end(); ++it) {
            if (it->first.compare(0, prefix.size(), prefix) != 0) break;
            size_t stop = it->first.find('-', stem.size());
            size_t length = stop == std::string::npos ? std::string::npos : stop - stem.size();
            std::string full = it->first.substr(stem.size(), length);
            if (std::find(seen.begin(), seen.end(), full) != seen.end()) continue;
            visit(full, stem + full);
            seen.push_back(std::move(full));
        }
    }

    PhraseTable table_;
    std::vector<Partial> root_;
    UserPhrases user_;
    std::vector<char> starts_; // 音（四個部分合成的數字）→ 有沒有這個開頭
};

} // namespace DouJian
