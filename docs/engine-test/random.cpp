// 5. 狀態：隨機操作，跟改之前的引擎比（不帶 alternatives 時要一模一樣），也跟「照按鍵紀錄重打一次」比
#include "common.h"
using namespace DouJian;

static std::string joinKeys(const std::vector<KeyEvent> &keys) {
    std::string s;
    for (auto &k : keys) s += k.sealed ? kToneOneMark : k.symbol.composedString();
    return s;
}
static int errors = 0;
static void fail(const char *what, const Strings &log) {
    if (errors++ > 10) return;
    printf("FAIL %s:", what);
    for (auto &l : log) printf(" %s", l.c_str());
    printf("\n");
}

// 按鍵紀錄跟格子、buffer 一對一；照紀錄重打一次會得到一樣的斷音
static void check(ComposingSession &s, FuzzyToneLM &lm, const Strings &log) {
    if (s.keys().size() != s.readings().size()) return fail("count", log);
    for (size_t i = 0; i < s.keys().size(); i++) if (joinKeys(s.keys()[i].keys) != s.readings()[i]) return fail("reading", log);
    if (joinKeys(s.bufferKeys()) != s.bufferReading()) return fail("buffer", log);
    // 重打：跟某個鍵換成自己一樣，斷出來要跟現在一樣
    std::vector<SyllableKeys> all = s.keys();
    Strings typed = s.readings();
    if (!s.bufferReading().empty()) { all.push_back({s.bufferKeys(), false}); typed.push_back(s.bufferReading()); }
    KeyCorrection c(lm);
    bool toneOnly = false;
    for (auto &t : typed) if (stage(BPMF::FromComposedString(t)) == 4 && !BPMF::FromComposedString(t).hasConsonant() && !BPMF::FromComposedString(t).hasVowel() && !BPMF::FromComposedString(t).hasMiddleVowel()) toneOnly = true;
    if (!toneOnly) {
        for (size_t i = 0; i < all.size(); i++) for (size_t k = 0; k < all[i].keys.size(); k++) {
            if (all[i].keys[k].sealed) continue;
            auto r = c.resegment(all, typed, {i, k, {all[i].keys[k].symbol, 0}});
            if (!r || *r != typed) return fail("replay", log);
        }
        // 從頭重打、一個鍵換成別的：從前一個音開始重打，要跟整個從頭重打一樣
        if (!all.empty()) {
            static const char *pool[] = {"ㄅ","ㄐ","ㄧ","ㄨ","ㄢ","ㄥ","ˇ","ˊ","ㄕ"};
            for (size_t i = 0; i < all.size(); i++) for (size_t k = 0; k < all[i].keys.size(); k++) {
                if (all[i].keys[k].sealed) continue;
                BPMF sym = BPMF::FromComposedString(pool[(i * 7 + k * 3 + log.size()) % 9]);
                auto r = c.resegment(all, typed, {i, k, {sym, 0}});
                // 樸素版
                Strings out; BPMF buf; bool bad = false;
                for (size_t x = 0; x < all.size() && !bad; x++) {
                    for (size_t y = 0; y < all[x].keys.size() && !bad; y++) {
                        if (all[x].keys[y].sealed) { if (buf.isEmpty()) bad = true; else out.push_back(buf.composedString() + kToneOneMark); buf.clear(); continue; }
                        BPMF in = x == i && y == k ? sym : all[x].keys[y].symbol;
                        if (startsNewSyllable(lm, buf, in)) { if (!buf.isEmpty()) out.push_back(buf.composedString()); buf.clear(); }
                        if (buf.isEmpty() && in.hasToneMarker()) bad = true;
                        buf += in;
                        if (in.hasToneMarker()) { out.push_back(buf.composedString()); buf.clear(); }
                    }
                    if (all[x].closed) { if (!buf.isEmpty()) out.push_back(buf.composedString()); buf.clear(); }
                }
                if (!buf.isEmpty()) out.push_back(buf.composedString());
                if (bad != !r || (!bad && *r != out)) return fail("resegment", log);
            }
        }
    }
    // 候選的基本規矩
    size_t total = typed.size();
    std::set<std::string> seen;
    for (auto &cand : s.candidates()) {
        if (!seen.insert(cand.value).second) return fail("dup candidate", log);
        if (cand.corrected && cand.span != total) return fail("corrected span", log);
        if (cand.corrected && cand.reading.empty()) return fail("corrected reading", log);
    }
    if (s.defaultCount() > s.candidates().size()) return fail("default", log);
}

int randomTest(int rounds) {
    Layout layout;
    std::mt19937 rng(2026);
    ComposingSession a, plain; orig::Session b; FuzzyToneLM lm;
    a.open("data.txt"); plain.open("data.txt"); b.open("data.txt"); lm.open("data.txt");
    auto words = loadItems("words3.txt");
    std::vector<std::string> sentenceKeys;
    size_t ops = 0, corrected = 0, pickedCorrected = 0, seals = 0, drops = 0, partials = 0, prefs = 0, oldBug = 0, rescued = 0;
    for (int round = 0; round < rounds; round++) {
        a.clear(); plain.clear(); b.clear();
        Strings log;
        bool synced = true, withOld = true; // 選了修正之後 a 跟 plain 就不同步了；withOld：舊引擎還跟得上
        Strings queue;
        int len = 5 + rng() % 40;
        for (int i = 0; i < len; i++) {
            ops++;
            int dice = rng() % 100;
            if (dice < 72) {
                std::string sym;
                if (rng() % 100 < 70) {
                    if (queue.empty()) { queue = keysFor(words[rng() % words.size()].reading, rng() % 2); std::reverse(queue.begin(), queue.end()); }
                    sym = queue.back(); queue.pop_back();
                } else sym = layout.keys[rng() % layout.keys.size()].symbol;
                const Key &k = layout.keys[layout.index.at(sym)];
                double px = k.cx() + (int)(rng() % 35) - 17, py = k.cy() + (int)(rng() % 50) - 25;
                size_t before = a.readings().size() + (a.bufferReading().empty() ? 0 : 1);
                a.feed(sym, layout.alternatives(px, py, layout.index.at(sym), 1.0, 6));
                if (synced) { plain.feed(sym, {}); b.feed(sym); }
                // 打完的音不存在、換鄰鍵救回來的：沒帶 alternatives 的引擎沒有這個音
                if (synced && a.readings().size() != plain.readings().size()) { synced = false; rescued++; }
                else if (synced && a.composing() != plain.composing()) { synced = false; rescued++; }
                if (a.readings().size() + (a.bufferReading().empty() ? 0 : 1) < before) drops++;
                log.push_back(sym);
            } else if (dice < 85) {
                bool x = a.backspace();
                if (synced) { bool y = plain.backspace(), z = b.backspace(); if (x != y || (withOld && y != z)) fail("backspace ret", log); }
                log.push_back("<");
            } else if (dice < 90) {
                bool x = a.canSealFirstTone(); seals += x;
                a.sealFirstTone();
                if (synced) { if (plain.canSealFirstTone() != x || (withOld && b.canSealFirstTone() != x)) fail("canSeal", log); plain.sealFirstTone(); b.sealFirstTone(); }
                log.push_back("_");
            } else if (dice < 97) {
                if (a.candidates().empty()) continue;
                size_t idx = rng() % std::min<size_t>(a.candidates().size(), rng() % 2 ? 4 : 60);
                auto cand = a.candidates()[idx];
                size_t total = a.readings().size() + (a.bufferReading().empty() ? 0 : 1);
                std::string v = a.select(idx);
                if (v != cand.value) fail("select value", log);
                log.push_back("#" + std::to_string(idx) + cand.value);
                if (cand.corrected) {
                    pickedCorrected++;
                    if (!a.composing().empty() || !a.candidates().empty()) fail("corrected leaves rest", log);
                    if (a.lastSelectedReading() != cand.reading || cand.reading.empty()) fail("corrected reading", log);
                    synced = false;
                } else {
                    if (cand.span < total) partials++;
                    if (synced) {
                        // 在不帶 alternatives 的引擎找同一個字選下去
                        size_t pi = 0, bi = 0;
                        while (pi < plain.candidates().size() && plain.candidates()[pi].value != v) pi++;
                        while (bi < b._candidateCache.size() && b._candidateCache[bi].value != v) bi++;
                        if (pi == plain.candidates().size()) fail("missing in plain", log);
                        plain.select(pi);
                        if (bi < b._candidateCache.size()) { b.select(bi); if (withOld && a.lastSelectedReading() != b._lastSelectedReading) fail("last reading", log); }
                        else withOld = false; // 簡拼才有的候選，舊引擎沒有
                        // 舊引擎的錯：照字元數算佔幾個音，1️⃣ 這種表情會多吃後面的音
                        if (DouJian::splitUTF8(v).size() != cand.span) withOld = false;
                    }
                }
            } else if (dice < 98) {
                a.clear(); plain.clear(); b.clear(); synced = true; withOld = true;
                log.push_back("clear");
            } else {
                Strings pref;
                if (!a.candidates().empty() && rng() % 2) pref.push_back(a.candidates()[rng() % std::min<size_t>(8, a.candidates().size())].value);
                prefs++;
                a.setPreferred(pref); plain.setPreferred(pref); b.setPreferred(pref);
                log.push_back("pref");
            }
            if (a.composing().empty()) { plain.clear(); b.clear(); synced = true; withOld = true; }
            for (auto &c : a.candidates()) if (c.corrected) { corrected++; break; }
            check(a, lm, log);
            // 舊引擎的錯：正在打的音收不進格子（ㄈㄧ）時會多刪前一個音
            if (!a.bufferReading().empty() && !lm.hasUnigrams(a.bufferReading())) { withOld = false; oldBug++; }
            if (synced) {
                check(plain, lm, log);
                if (a.composing() != plain.composing() || (withOld && a.composing() != b.composing())) { if (errors < 3) printf("[%s] [%s] [%s] ", a.composing().c_str(), plain.composing().c_str(), b.composing().c_str()); fail("composing", log); }
                if (withOld && a.composingStage() != b.composingStage()) fail("stage", log);
                // 拿掉修正的候選之後，剩下的要跟沒有 alternatives 的一樣（順序也一樣）
                Strings x, y;
                for (auto &c : a.candidates()) if (!c.corrected) x.push_back(c.value);
                std::set<std::string> moved;
                for (auto &c : a.candidates()) if (c.corrected) moved.insert(c.value);
                for (auto &c : plain.candidates()) if (!moved.count(c.value)) y.push_back(c.value);
                if (x != y) fail("rest of candidates", log);
            }
        }
    }
    {
        // 列出「有這個開頭、自己查不到」的音
        printf("dead syllables:");
        for (int c = 0; c < 22; c++) for (int m = 0; m < 4; m++) for (int v = 0; v < 14; v++) {
            BPMF y(static_cast<BPMF::Component>(c | (m << 5) | (v << 7)));
            if (y.isEmpty() || !lm.isSyllableStart(y)) continue;
            if (!lm.hasUnigrams(y.composedString())) printf(" %s", y.composedString().c_str());
        }
        printf("\n");
    }
    printf("old-engine deletes previous syllable: %zu, rescued syllables %zu\n", oldBug, rescued);
    printf("random: rounds %d ops %zu errors %d | corrected visible %zu, picked corrected %zu, seals %zu, dropped syllables %zu, partial picks %zu, preferred changes %zu\n",
           rounds, ops, errors, corrected, pickedCorrected, seals, drops, partials, prefs);
    return errors ? 1 : 0;
}
