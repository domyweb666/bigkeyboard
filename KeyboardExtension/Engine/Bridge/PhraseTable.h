#pragma once

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <string>
#include <string_view>

#include "MemoryMappedFile.h"
#include "ParselessPhraseDB.h"

namespace DouJian {

// 詞庫裡連續的幾行（begin 在行首、end 在某一行的行首或檔尾）
struct Rows {
    const char *begin = nullptr;
    const char *end = nullptr;

    bool empty() const { return begin == end; }
};

// 小麥詞庫（「讀音 詞 分數」照讀音的位元組順序排好、同讀音分數高到低），用 mmap 直接查。
// 跟小麥自己的 ParselessPhraseDB 差在：可以只在一小段裡面找。一個音一個音往下接時，每接一個音範圍就小一截。
class PhraseTable {
public:
    bool open(const char *path) {
        if (!file_.open(path)) return false;
        all_ = {file_.data(), file_.data() + file_.length()};
        if (!McBopomofo::ParselessPhraseDB::ValidatePragma(file_.data(), file_.length())) {
            all_.end = all_.begin;
        } else {
            all_.begin += McBopomofo::SORTED_PRAGMA_HEADER.length();
        }
        return true;
    }

    Rows all() const { return all_; }

    // within 裡以 key 開頭的那幾行
    Rows startingWith(const Rows &within, std::string_view key) const {
        const char *first = partition(within, key, false);
        if (first == within.end || compare(first, key) != 0) return {first, first};
        return {first, partition({first, within.end}, key, true)};
    }

    bool hasPrefix(const Rows &within, std::string_view key) const {
        const char *first = partition(within, key, false);
        return first != within.end && compare(first, key) == 0;
    }

    // 一行一行看：visit(詞, 分數)，回傳 false 就停
    template <class F>
    void forEach(const Rows &rows, F visit) const {
        for (const char *p = rows.begin; p < rows.end;) {
            const char *eol = lineEnd(p);
            const char *word = std::find(p, eol, ' ');
            if (word != eol) word++;
            const char *wordEnd = std::find(word, eol, ' ');
            double score = wordEnd == eol ? 0 : parseScore(wordEnd + 1, eol);
            if (!visit(std::string_view(word, wordEnd - word), score)) return;
            p = eol == rows.end ? eol : eol + 1;
        }
    }

private:
    const char *lineEnd(const char *p) const {
        const void *hit = std::memchr(p, '\n', all_.end - p);
        return hit ? static_cast<const char *>(hit) : all_.end;
    }

    // 這一行的開頭跟 key 比：小於 0、等於 0（以 key 開頭）、大於 0
    int compare(const char *line, std::string_view key) const {
        size_t n = std::min(key.size(), static_cast<size_t>(all_.end - line));
        int c = std::memcmp(line, key.data(), n);
        return c == 0 && n < key.size() ? -1 : c;
    }

    // past = false：第一個不小於 key 的行；past = true：第一個大於「以 key 開頭」的行
    const char *partition(const Rows &within, std::string_view key, bool past) const {
        const char *lo = within.begin;
        const char *hi = within.end;
        while (lo < hi) {
            const char *line = lo + (hi - lo) / 2;
            while (line > lo && line[-1] != '\n') line--;
            int c = compare(line, key);
            if (c < 0 || (past && c == 0)) {
                const char *eol = lineEnd(line);
                lo = eol == all_.end ? eol : eol + 1;
            } else {
                hi = line;
            }
        }
        return lo;
    }

    static double parseScore(const char *begin, const char *end) {
        char text[32];
        size_t n = std::min(static_cast<size_t>(end - begin), sizeof(text) - 1);
        std::memcpy(text, begin, n);
        text[n] = 0;
        return std::strtod(text, nullptr);
    }

    McBopomofo::MemoryMappedFile file_;
    Rows all_;
};

} // namespace DouJian
