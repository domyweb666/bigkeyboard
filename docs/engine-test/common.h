#pragma once
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <map>
#include <random>
#include <set>
#include <string>
#include <vector>
#include "ComposingSession.h"
#include "orig_session.h"

using DouJian::ComposingSession;
using Strings = std::vector<std::string>;

struct Item { std::string text, reading; };
inline std::vector<Item> loadItems(const char *path) {
    std::ifstream f(path);
    std::vector<Item> out;
    std::string a, b;
    while (f >> a >> b) out.push_back({a, b});
    return out;
}
inline bool isTone(const std::string &s) { return s == "ˊ" || s == "ˇ" || s == "ˋ" || s == "˙"; }
// 讀音 → 要按的鍵；mode 0 打聲調、1 不打聲調、2 打聲調而且一聲按空白（"_"，能當一聲才有效）
inline Strings keysFor(const std::string &reading, int mode) {
    Strings out;
    bool first = true;
    for (auto &syl : DouJian::splitReading(reading)) {
        auto ch = DouJian::splitUTF8(syl);
        bool tone = false;
        // 輕聲以外的聲調都在後面；詞庫的 ˙ 也在後面
        for (auto &c : ch) {
            if (isTone(c)) { tone = true; if (mode == 1) continue; }
            out.push_back(c);
        }
        if (!tone && mode == 2) out.push_back("_");
        first = false;
    }
    (void)first;
    return out;
}
inline void feedKey(ComposingSession &s, const std::string &k, const ComposingSession::Alternatives &alts = {}) {
    if (k == "_") { if (s.canSealFirstTone()) s.sealFirstTone(); return; }
    s.feed(k, alts);
}
inline void feedKey(orig::Session &s, const std::string &k) {
    if (k == "_") { if (s.canSealFirstTone()) s.sealFirstTone(); return; }
    s.feed(k);
}
inline std::string top(const ComposingSession &s) { return s.candidates().empty() ? "" : s.candidates()[0].value; }
inline std::string top(const orig::Session &s) { return s._candidateCache.empty() ? "" : s._candidateCache[0].value; }

// ---- 鍵盤幾何（393×852 的手機）----
struct Key { std::string symbol; double x, y, w, h; int group; double cx() const { return x + w / 2; } double cy() const { return y + h / 2; } };
struct Layout {
    std::vector<Key> keys;
    std::map<std::string, size_t> index;
    double pitchX = 35.45, pitchY = 53.2;
    Layout() {
        std::vector<Strings> rows = {
            {"ㄅ","ㄉ","ˇ","ˋ","ㄓ","ˊ","˙","ㄚ","ㄞ","ㄢ","ㄦ"},
            {"ㄆ","ㄊ","ㄍ","ㄐ","ㄔ","ㄗ","ㄧ","ㄛ","ㄟ","ㄣ"},
            {"ㄇ","ㄋ","ㄎ","ㄑ","ㄕ","ㄘ","ㄨ","ㄜ","ㄠ","ㄤ"},
            {"ㄈ","ㄌ","ㄏ","ㄒ","ㄖ","ㄙ","ㄩ","ㄝ","ㄡ","ㄥ"}};
        for (int r = 0; r < 4; r++) {
            bool st = r == 1 || r == 2;
            double w = st ? 30.0 : (385.0 - 50) / 11, p = w + 5, x0 = 4 + (st ? 20.0 : 0);
            for (size_t i = 0; i < rows[r].size(); i++) {
                const auto &s = rows[r][i];
                auto b = DouJian::BPMF::FromComposedString(s);
                index[s] = keys.size();
                keys.push_back({s, x0 + i * p, 7 + r * 53.2, w, 46.2, DouJian::stage(b)});
            }
        }
    }
    // 離最近的鍵（照 nearestKey：打了聲母後介音、韻母多吃 10pt；打了介音後只有韻母）
    size_t hit(double px, double py, int stage) const {
        size_t best = 0; double bd = 1e9;
        for (size_t i = 0; i < keys.size(); i++) {
            const auto &k = keys[i];
            double dx = std::max({k.x - px, 0.0, px - k.x - k.w}), dy = std::max({k.y - py, 0.0, py - k.y - k.h});
            double d = std::sqrt(dx * dx + dy * dy);
            if ((stage == 1 && (k.group == 2 || k.group == 3)) || (stage == 2 && k.group == 3)) d -= 10;
            if (d < bd) { bd = d; best = i; }
        }
        return best;
    }
    ComposingSession::Alternatives alternatives(double px, double py, size_t pressed, double base, double maxCost,
                                                double sigma = 0.28, size_t count = 3) const {
        double sx = sigma * pitchX, sy = sigma * pitchY;
        auto d2 = [&](const Key &k) {
            double a = (px - k.cx()) / sx, b = (py - k.cy()) / sy;
            return a * a + b * b;
        };
        double own = d2(keys[pressed]);
        ComposingSession::Alternatives out;
        for (size_t i = 0; i < keys.size(); i++) {
            if (i == pressed) continue;
            double c = std::max(base, base + 0.434 / 2 * (d2(keys[i]) - own));
            if (c <= maxCost) out.push_back({keys[i].symbol, c});
        }
        std::stable_sort(out.begin(), out.end(), [](auto &a, auto &b) { return a.second < b.second; });
        if (out.size() > count) out.resize(count);
        return out;
    }
};
inline double nowMs() {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now().time_since_epoch()).count();
}
