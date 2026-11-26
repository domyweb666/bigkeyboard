#include "common.h"
#include <cstring>
#ifdef TUNE
using DouJian::OmissionPenalty;
using DouJian::CorrectionTuning;
#endif

static const char *kData = "data.txt";
static double argOf(int argc, char **argv, const char *name, double def) {
    for (int i = 2; i + 1 < argc; i++) if (!std::strcmp(argv[i], name)) return std::atof(argv[i + 1]);
    return def;
}
static const char *strOf(int argc, char **argv, const char *name, const char *def) {
    for (int i = 2; i + 1 < argc; i++) if (!std::strcmp(argv[i], name)) return argv[i + 1];
    return def;
}

// 假裝學過 count 個詞
static DouJian::UserPhrases learned(int count) {
    DouJian::UserPhrases phrases;
    auto pool = loadItems("words2.txt"); auto p3 = loadItems("words3.txt");
    pool.insert(pool.end(), p3.begin(), p3.end());
    std::mt19937 r(3);
    for (int i = 0; i < count; i++) { auto &it = pool[r() % pool.size()]; phrases[it.reading] = {DouJian::Unigram(it.text, 0)}; }
    return phrases;
}

// 1. 回歸。users：帶幾個學過的詞（簡拼曾經讓學過的詞蓋掉不同音的常用詞，空字典測不到）
static void regress(int argc, char **argv) {
    auto phrases = learned((int)argOf(argc, argv, "users", 0));
    std::vector<std::pair<std::string, std::string>> pairs;
    for (auto &p : phrases) pairs.emplace_back(p.first, p.second.front().value());
    for (const char *file : {"sents.txt", "sents2.txt", "top1.txt", "top2.txt", "top3.txt", "top4.txt", "names.txt"}) {
        auto items = loadItems(file);
        for (int mode = 0; mode < 3; mode++) {
            ComposingSession a; orig::Session b;
            a.open(kData); b.open(kData);
            a.setUserPhrases(phrases); b.setUserPhrases(pairs);
            size_t same = 0, keys = 0, keySame = 0, comp = 0, defaults = 0, list = 0, shown = 0;
            for (auto &it : items) {
                a.clear(); b.clear();
                bool compOk = true;
                for (auto &k : keysFor(it.reading, mode)) {
                    feedKey(a, k); feedKey(b, k);
                    keys++;
                    keySame += top(a) == top(b);
                    compOk &= a.composing() == b.composing() && a.composingStage() == b.composingStage();
                }
                comp += compOk;
                defaults += a.defaultCount() == b._defaultCandidateCount;
                // 佔幾個音：舊引擎照字元數算（1️⃣ 算 3 個），這種候選不比 span
                bool ls = true;
                for (size_t i = 0; i < 5 && i < b._candidateCache.size(); i++)
                    ls &= i < a.candidates().size() && a.candidates()[i].value == b._candidateCache[i].value
                        && (a.candidates()[i].span == b._candidateCache[i].span || DouJian::splitUTF8(a.candidates()[i].value).size() != a.candidates()[i].span) && a.candidates()[i].reading == b._candidateCache[i].reading;
                list += ls;
                if (top(a) == top(b)) same++;
                else if (shown++ < 12) printf("   DIFF [%s m%d] want %s  before %s  after %s\n", file, mode, it.text.c_str(), top(b).c_str(), top(a).c_str());
            }
            printf("%s mode %d: n=%zu final-same %.2f%% key-same %.3f%% composing-same %.2f%% default-same %.2f%% top5-same %.2f%%\n", file, mode,
                   items.size(), 100.0 * same / items.size(), 100.0 * keySame / keys, 100.0 * comp / items.size(), 100.0 * defaults / items.size(), 100.0 * list / items.size());
        }
    }
}

// 2. 簡拼：每個音只打第一個符號（聲母；沒有聲母的音打完整韻母、介音開頭只打介音）
static void abbr(int argc, char **argv) {
    bool base = argOf(argc, argv, "base", 0) > 0;
    auto run = [&](const char *file, bool strict, bool lastFull) {
        auto items = loadItems(file);
        ComposingSession a; orig::Session b;
        a.open(kData); b.open(kData);
        size_t n = 0, r1 = 0, r3 = 0, r8 = 0, any = 0, b1 = 0, b3 = 0, b8 = 0;
        for (auto &it : items) {
            auto syl = DouJian::splitReading(it.reading);
            Strings keys; bool onlyConsonant = true;
            std::vector<std::string> expectComp;
            for (size_t i = 0; i < syl.size(); i++) {
                auto ch = DouJian::splitUTF8(syl[i]);
                auto b0 = DouJian::BPMF::FromComposedString(ch[0]);
                if (!b0.hasConsonant()) onlyConsonant = false;
                if (lastFull && i + 1 == syl.size()) { for (auto &c : ch) if (!isTone(c)) keys.push_back(c); }
                else if (b0.hasVowel()) { for (auto &c : ch) if (!isTone(c)) keys.push_back(c); }
                else keys.push_back(ch[0]);
            }
            if (strict && !onlyConsonant) continue;
            n++;
            a.clear(); b.clear();
            for (auto &k : keys) { feedKey(a, k); if (base) feedKey(b, k); }
            int pa = -1, pb = -1;
            for (size_t i = 0; i < a.candidates().size(); i++) if (a.candidates()[i].value == it.text) { pa = (int)i; break; }
            for (size_t i = 0; i < b._candidateCache.size(); i++) if (b._candidateCache[i].value == it.text) { pb = (int)i; break; }
            r1 += pa == 0; r3 += pa >= 0 && pa < 3; r8 += pa >= 0 && pa < 8; any += pa >= 0;
            b1 += pb == 0; b3 += pb >= 0 && pb < 3; b8 += pb >= 0 && pb < 8;
        }
        printf("%s %s%s n=%zu  after 1/3/8/any: %.1f/%.1f/%.1f/%.1f   before 1/3/8: %.1f/%.1f/%.1f\n", file, strict ? "all-consonant" : "any", lastFull ? " last-full" : "", n,
               100.0 * r1 / n, 100.0 * r3 / n, 100.0 * r8 / n, 100.0 * any / n, 100.0 * b1 / n, 100.0 * b3 / n, 100.0 * b8 / n);
    };
    for (const char *f : {"top2.txt", "top3.txt", "top4.txt", "words2.txt", "words3.txt", "words4.txt"}) run(f, true, false);
    for (const char *f : {"words2.txt", "words3.txt", "words4.txt"}) { run(f, false, false); run(f, true, true); }
    ComposingSession a; a.open(kData);
    std::vector<Strings> cases = {{"ㄒ","ㄒ"}, {"ㄒ","ㄒ","ㄋ"}, {"ㄅ","ㄏ","ㄧ","ㄙ"}, {"ㄊ","ㄅ","ㄕ"}, {"ㄓ","ㄒ"}, {"ㄕ","ㄐ"}, {"ㄕ","ㄇ"}, {"ㄨ","ㄇ"},
        {"ㄉ","ㄋ","ㄠ"}, {"ㄐ","ㄊ"}, {"ㄧ","ㄍ"}, {"ㄧ","ㄥ","ㄍ"}, {"ㄒ","ㄒ","ㄋ","ㄅ","ㄇ"}};
    for (auto &c : cases) {
        a.clear();
        for (auto &k : c) feedKey(a, k);
        printf("  %s →", a.composing().c_str());
        for (size_t i = 0; i < 10 && i < a.candidates().size(); i++) printf(" %s", a.candidates()[i].value.c_str());
        printf("  (span0 %zu, reading0 %s, total %zu)\n", a.candidates()[0].span, a.candidates()[0].reading.c_str(), a.candidates().size());
    }
}

// 2b. 只有最後一個音只打聲母（原本就有的）：前面打完整，改前改後想要的詞排第幾
static void lastOnly() {
    for (const char *file : {"words2.txt", "words3.txt", "words4.txt"}) for (int mode = 0; mode < 2; mode++) {
        auto items = loadItems(file);
        ComposingSession a; orig::Session b; a.open(kData); b.open(kData);
        size_t n = 0, a1 = 0, a3 = 0, a8 = 0, b1 = 0, b3 = 0, b8 = 0, worse = 0, better = 0;
        for (auto &it : items) {
            auto syl = DouJian::splitReading(it.reading);
            std::string head; for (size_t i = 0; i + 1 < syl.size(); i++) head += (i ? "-" : "") + syl[i];
            auto ch = DouJian::splitUTF8(syl.back());
            if (!DouJian::BPMF::FromComposedString(ch[0]).hasConsonant()) continue;
            auto keys = keysFor(head, mode); keys.push_back(ch[0]);
            a.clear(); b.clear();
            for (auto &k : keys) { feedKey(a, k); feedKey(b, k); }
            int pa = 9999, pb = 9999;
            for (size_t i = 0; i < a.candidates().size(); i++) if (a.candidates()[i].value == it.text) { pa = (int)i; break; }
            for (size_t i = 0; i < b._candidateCache.size(); i++) if (b._candidateCache[i].value == it.text) { pb = (int)i; break; }
            n++; a1 += pa < 1; a3 += pa < 3; a8 += pa < 8; b1 += pb < 1; b3 += pb < 3; b8 += pb < 8; worse += pa > pb; better += pa < pb;
        }
        printf("last-only %s m%d n=%zu before %.1f/%.1f/%.1f after %.1f/%.1f/%.1f  lower %zu higher %zu\n", file, mode, n, 100.0*b1/n, 100.0*b3/n, 100.0*b8/n, 100.0*a1/n, 100.0*a3/n, 100.0*a8/n, worse, better);
    }
}

// 3. 容錯
static void tolerance(int argc, char **argv) {
    const char *file = strOf(argc, argv, "file", "sents.txt");
    int draws = (int)argOf(argc, argv, "draws", 4);
    double base = argOf(argc, argv, "base", 1.5), maxCost = argOf(argc, argv, "max", 4);
    double sigmaAssume = argOf(argc, argv, "assume", 0.28);
    size_t count = (size_t)argOf(argc, argv, "count", 3);
    int onlyMode = (int)argOf(argc, argv, "mode", -1);
    int verbose = (int)argOf(argc, argv, "v", 0);
    double sOnly = argOf(argc, argv, "sigma", 0);
    double wide = argOf(argc, argv, "wide", 0); // 落點離想按的鍵最多幾 σ（0 不限）
    (void)wide;
    auto items = loadItems(file);
    Layout layout;
    int users = (int)argOf(argc, argv, "users", 0);
    ComposingSession a, plain;
    a.open(kData); plain.open(kData);
    if (users) {
        a.setUserPhrases(learned(users)); plain.setUserPhrases(learned(users));
    }
    for (int mode = 0; mode < 2; mode++) {
        if (onlyMode >= 0 && mode != onlyMode) continue;
        for (double sigma : {8.0, 10.0, 12.0}) {
            if (sOnly && sigma != sOnly) continue;
            std::mt19937 rng(42);
            std::normal_distribution<double> nd(0, 1);
            size_t n = 0, okNo = 0, okYes = 0, clean = 0, fp = 0, keys = 0, wrongKeys = 0, one = 0, oneNo = 0, oneYes = 0, broke = 0, flick = 0, cleanKeys = 0, near = 0, nearKeys = 0, shown = 0, lost = 0, in5 = 0, in5no = 0;
            for (auto &it : items) {
                auto ks = keysFor(it.reading, mode);
                plain.clear();
                Strings wantEach;
                for (auto &k : ks) { feedKey(plain, k); wantEach.push_back(top(plain)); }
                std::string want = wantEach.back();
                for (int d = 0; d < draws; d++) {
                    a.clear(); plain.clear();
                    int wrong = 0; bool lostHere = false;
                    size_t flickHere = 0, nearHere = 0;
                    for (size_t i = 0; i < ks.size(); i++) {
                        const Key &k = layout.keys[layout.index.at(ks[i])];
                        double px = k.cx() + sigma * nd(rng), py = k.cy() + sigma * nd(rng);
                        size_t h = layout.hit(px, py, a.composingStage());
                        if (layout.keys[h].symbol != ks[i]) wrong++;
                        size_t before = a.readings().size() + (a.bufferReading().empty() ? 0 : 1);
                        feedKey(a, layout.keys[h].symbol, layout.alternatives(px, py, h, base, maxCost, sigmaAssume, count));
                        if (a.readings().size() + (a.bufferReading().empty() ? 0 : 1) < before) lostHere = true;
                        feedKey(plain, layout.keys[h].symbol);
                        if (wrong == 0) {
                            flickHere += top(a) != top(plain);
                            for (auto &c : a.candidates()) if (c.corrected) { nearHere++; break; }
                        }
                    }
                    n++; keys += ks.size(); wrongKeys += wrong;
                    bool no = top(plain) == want, yes = top(a) == want;
                    okNo += no; okYes += yes;
                    broke += no && !yes;
                    if (no && !yes && verbose > 100 && wrong == 1) printf("   BROKE m%d %s -> %s [%s] vs [%s]\n", mode, want.c_str(), top(a).c_str(), a.composing().c_str(), plain.composing().c_str());
                    lost += lostHere;
                    if (wrong == 0) {
                        clean++; cleanKeys += ks.size(); flick += flickHere; nearKeys += nearHere;
                        bool changed = top(a) != want;
                        fp += changed;
                        if (changed && verbose && shown++ < (size_t)verbose) printf("   FP m%d s%.0f %s → %s\n", mode, sigma, want.c_str(), top(a).c_str());
                    }
                    if (wrong == 1) {
                        one++; oneNo += no; oneYes += yes;
                        for (size_t i = 0; i < 5 && i < a.candidates().size(); i++) in5 += a.candidates()[i].value == want;
                        for (size_t i = 0; i < 5 && i < plain.candidates().size(); i++) in5no += plain.candidates()[i].value == want;
                    }
                }
            }
            printf("%s m%d s%.0f base %.2f max %.1f assume %.2f cnt %zu | n=%zu key-err %.2f%% | all ok: no %.2f%% yes %.2f%% | 1-err (n=%zu): no %.1f%% yes %.1f%% | clean n=%zu altered %.3f%% (%zu) | mid-key altered %.2f%% corrected-visible %.2f%% | broke %.2f%% lost-syl %.2f%% | 1-err in5 no %.1f%% yes %.1f%%\n",
                   file, mode, sigma, base, maxCost, sigmaAssume, count, n, 100.0 * wrongKeys / keys, 100.0 * okNo / n, 100.0 * okYes / n, one, 100.0 * oneNo / std::max<size_t>(1, one), 100.0 * oneYes / std::max<size_t>(1, one),
                   clean, 100.0 * fp / std::max<size_t>(1, clean), fp, 100.0 * flick / std::max<size_t>(1, cleanKeys), 100.0 * nearKeys / std::max<size_t>(1, cleanKeys), 100.0 * broke / n, 100.0 * lost / n, 100.0 * in5no / std::max<size_t>(1, one), 100.0 * in5 / std::max<size_t>(1, one));
            fflush(stdout);
        }
    }
}

// 4. 速度：20 個鍵左右的長句逐鍵打
static void speed(int argc, char **argv) {
    auto items = loadItems("sents.txt");
    auto more = loadItems("sents2.txt");
    items.insert(items.end(), more.begin(), more.end());
    double base = argOf(argc, argv, "base", 1.5), maxCost = argOf(argc, argv, "max", 4);
    Layout layout;
    for (int mode = 0; mode < 2; mode++) {
        std::vector<Strings> texts;
        for (auto &it : items) { auto k = keysFor(it.reading, mode); if (k.size() >= 20) { k.resize(20); texts.push_back(k); } if (texts.size() == 60) break; }
        if (texts.size() < 60) for (size_t i = 0; i + 1 < items.size() && texts.size() < 60; i += 2) { auto k = keysFor(items[i].reading + "-" + items[i + 1].reading, mode); if (k.size() >= 20) { k.resize(20); texts.push_back(k); } }
        for (int cold = 1; cold >= 0; cold--) {
            // cold：每句都是新的引擎（什麼都沒記起來）；warm：同一個引擎一路打下去
            struct R { double sum = 0, worst = 0; std::vector<double> all; } rs[3];
            for (int which = 0; which < 3; which++) for (int rep = 0; rep < 5; rep++) {
                size_t at = 0;
                std::unique_ptr<ComposingSession> a; std::unique_ptr<orig::Session> b;
                std::mt19937 rng(1); std::normal_distribution<double> nd(0, 1);
                bool first = true;
                for (auto &t : texts) {
                    if (cold || first) {
                        if (which == 0) { b = std::make_unique<orig::Session>(); b->open(kData); }
                        else { a = std::make_unique<ComposingSession>(); a->open(kData); }
                        first = false;
                    }
                    if (a) a->clear();
                    if (b) b->clear();
                    for (auto &k : t) {
                        const Key &kk = layout.keys[layout.index.at(k)];
                        double px = kk.cx() + 10 * nd(rng), py = kk.cy() + 10 * nd(rng);
                        auto alts = which == 2 ? layout.alternatives(px, py, layout.index.at(k), base, maxCost) : ComposingSession::Alternatives{};
                        double t0 = nowMs();
                        if (which == 0) b->feed(k); else a->feed(k, alts);
                        double dt = nowMs() - t0;
                        if (rep == 0) rs[which].all.push_back(dt); else rs[which].all[at] = std::min(rs[which].all[at], dt);
                        at++;
                    }
                }
            }
            const char *names[] = {"before", "after(no alt)", "after(alts)"};
            for (int w = 0; w < 3; w++) {
                auto &v = rs[w].all; std::sort(v.begin(), v.end());
                rs[w].worst = v.back(); for (double x : v) rs[w].sum += x;
                printf("mode %d %s %-14s n=%zu avg %.3f p95 %.3f p99 %.3f worst %.3f ms\n", mode, cold ? "cold" : "warm", names[w], v.size(), rs[w].sum / v.size(), v[v.size() * 95 / 100], v[v.size() * 99 / 100], rs[w].worst);
            }
        }
    }
    // 簡拼最吃力的：全打聲母 8 個音
    printf("abbreviation typing:\n");
    for (auto seq : std::vector<Strings>{{"ㄕ","ㄕ","ㄕ","ㄕ","ㄕ","ㄕ","ㄕ","ㄕ"}, {"ㄒ","ㄒ","ㄒ","ㄒ","ㄒ","ㄒ","ㄒ","ㄒ"}, {"ㄕ","ㄐ","ㄕ","ㄐ","ㄓ","ㄒ","ㄉ","ㄕ"}, {"ㄧ","ㄧ","ㄧ","ㄨ","ㄨ","ㄧ","ㄨ","ㄩ"}}) {
        ComposingSession a; a.open(kData); orig::Session b; b.open(kData);
        printf("  ");
        for (auto &k : seq) { double t0 = nowMs(); b.feed(k); double t1 = nowMs(); a.feed(k, {}); double t2 = nowMs(); printf("%s %.2f/%.2f ", k.c_str(), t1 - t0, t2 - t1); }
        printf("\n");
    }
}

// 7. 佔幾個音：一個音、但不只一個字元的候選（1️⃣、全形數字以外的符號…）選了只能吃掉一個音。
//    打「那個音＋ㄍㄜˋ」，選它之後格子要剩一個音（以前照字元數算，1️⃣ 會連 ㄍㄜˋ 一起吃掉）
static void spanCheck() {
    std::ifstream f(kData);
    std::string line, reading, value;
    size_t tried = 0, found = 0, bad = 0;
    std::set<std::string> done;
    ComposingSession a; a.open(kData);
    while (std::getline(f, line)) {
        // 一行一筆「讀音 字 分數」；第一行是 # 開頭的格式說明
        size_t s1 = line.find(' '), s2 = line.find(' ', s1 + 1);
        if (line.empty() || line[0] == '#' || s1 == std::string::npos || s2 == std::string::npos) continue;
        reading = line.substr(0, s1);
        value = line.substr(s1 + 1, s2 - s1 - 1);
        if (reading[0] == '_' || reading.find('-') != std::string::npos) continue;
        if (DouJian::splitUTF8(value).size() < 2 || !done.insert(value).second) continue;
        tried++;
        a.clear();
        for (auto &k : keysFor(reading, 0)) feedKey(a, k);
        for (auto &k : keysFor("ㄍㄜˋ", 0)) feedKey(a, k);
        const auto &list = a.candidates();
        size_t at = list.size();
        for (size_t i = 0; i < list.size(); i++) if (list[i].value == value) { at = i; break; }
        if (at == list.size()) continue;
        found++;
        a.select(at);
        if (a.readings().size() != 1) {
            if (bad++ < 12) printf("   BAD %s %s: left %zu readings\n", reading.c_str(), value.c_str(), a.readings().size());
        }
    }
    printf("span: tried %zu, in candidates %zu, ate too many %zu\n", tried, found, bad);
}

int main(int argc, char **argv) {
    std::string cmd = argc > 1 ? argv[1] : "";
#ifdef TUNE
    OmissionPenalty::consonant = argOf(argc, argv, "pc", OmissionPenalty::consonant);
    OmissionPenalty::syllabic = argOf(argc, argv, "ps", OmissionPenalty::syllabic);
    OmissionPenalty::syllabicInAbbreviation = argOf(argc, argv, "pa", OmissionPenalty::syllabicInAbbreviation);
    CorrectionTuning::nearMargin = argOf(argc, argv, "near", CorrectionTuning::nearMargin);
#endif
    if (cmd == "regress") regress(argc, argv);
    else if (cmd == "abbr") abbr(argc, argv);
    else if (cmd == "last") lastOnly();
    else if (cmd == "tol") tolerance(argc, argv);
    else if (cmd == "speed") speed(argc, argv);
    else if (cmd == "span") spanCheck();
    else if (cmd == "random") { extern int randomTest(int); return randomTest(argc > 2 ? std::atoi(argv[2]) : 2000); }
    return 0;
}
