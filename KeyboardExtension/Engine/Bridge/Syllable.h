#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "Mandarin/Mandarin.h"

// 一個音的小工具：符號怎麼接、走到哪一段、有沒有打聲調、算不算簡拼。純 C++，Windows 上也能編來測。
namespace DouJian {

using Formosa::Mandarin::BPMF;

// 注音符號 → 它在標準鍵盤上的 ASCII 鍵
inline char keyForSymbol(const std::string &symbol) {
    BPMF parsed = BPMF::FromComposedString(symbol);
    if (parsed.isEmpty()) return 0;
    BPMF::Component component = 0;
    if (parsed.hasConsonant()) component = parsed.consonantComponent();
    else if (parsed.hasMiddleVowel()) component = parsed.middleVowelComponent();
    else if (parsed.hasVowel()) component = parsed.vowelComponent();
    else if (parsed.hasToneMarker()) component = parsed.toneMarkerComponent();
    return Formosa::Mandarin::BopomofoKeyboardLayout::StandardLayout()->componentToKey(component);
}

// 一個音節「已經走到哪一段」：聲母 1 → 介音 2 → 韻母 3 → 聲調 4。新符號的段落若不比目前更後面，就該另起一音。
inline int stage(const BPMF &s) {
    if (s.hasToneMarker()) return 4;
    if (s.hasVowel()) return 3;
    if (s.hasMiddleVowel()) return 2;
    if (s.hasConsonant()) return 1;
    return 0;
}

// 一個音的四個部分合成一個數字（查表用）
inline uint16_t rawSyllable(const BPMF &s) {
    return static_cast<uint16_t>(
        s.consonantComponent() | s.middleVowelComponent() | s.vowelComponent() | s.toneMarkerComponent()
    );
}

// 空白鍵定成一聲的音，在格子裡的讀音後面接這個記號（詞庫裡一聲沒有記號，查詢前要拿掉）。
// 不帶記號、沒聲調的音是「哪一聲都可以」；帶記號的只查一聲。
inline const std::string kToneOneMark = "ˉ";

inline bool isSealedToneOne(const std::string &syllable) {
    return syllable.size() > kToneOneMark.size()
        && syllable.compare(syllable.size() - kToneOneMark.size(), kToneOneMark.size(), kToneOneMark) == 0;
}

inline std::string withoutToneOneMark(const std::string &reading) {
    std::string out;
    for (size_t pos = 0;;) {
        size_t hit = reading.find(kToneOneMark, pos);
        out += reading.substr(pos, hit == std::string::npos ? std::string::npos : hit - pos);
        if (hit == std::string::npos) return out;
        pos = hit + kToneOneMark.size();
    }
}

// 這個音是不是使用者自己打完的（打了聲調，或用空白鍵定成一聲）
inline bool hasToneMark(const std::string &syllable) {
    return isSealedToneOne(syllable) || BPMF::FromComposedString(syllable).hasToneMarker();
}

// 沒打完的音：只打聲母、自己不成音（ㄅㄒ…）；只打聲母、自己就是一個音（ㄓㄔㄕㄖㄗㄘㄙ）；只打介音（ㄧㄨㄩ）
enum class Omission { none, consonant, syllabicConsonant, medial };

inline Omission omission(const std::string &syllable) {
    if (isSealedToneOne(syllable)) return Omission::none;
    BPMF s = BPMF::FromComposedString(syllable);
    if (s.hasVowel() || s.hasToneMarker()) return Omission::none;
    if (s.hasConsonant()) {
        if (s.hasMiddleVowel()) return Omission::none;
        return s.belongsToZCSRClass() ? Omission::syllabicConsonant : Omission::consonant;
    }
    return s.hasMiddleVowel() ? Omission::medial : Omission::none;
}

inline bool isConsonantOnly(const std::string &syllable) {
    Omission o = omission(syllable);
    return o == Omission::consonant || o == Omission::syllabicConsonant;
}

// 把 UTF-8 字串拆成一個一個字元
inline std::vector<std::string> splitUTF8(const std::string &s) {
    std::vector<std::string> out;
    for (size_t i = 0; i < s.size();) {
        unsigned char c = s[i];
        size_t len = (c < 0x80) ? 1 : (c >> 5) == 0x6 ? 2 : (c >> 4) == 0xE ? 3 : 4;
        out.push_back(s.substr(i, len));
        i += len;
    }
    return out;
}

// "ㄅㄨ-ㄧㄠˋ" → {"ㄅㄨ", "ㄧㄠˋ"}
inline std::vector<std::string> splitReading(const std::string &reading) {
    std::vector<std::string> out;
    size_t start = 0;
    for (size_t i = 0; i <= reading.size(); i++) {
        if (i == reading.size() || reading[i] == '-') {
            out.push_back(reading.substr(start, i - start));
            start = i + 1;
        }
    }
    return out;
}

} // namespace DouJian
