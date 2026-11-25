#pragma once

#include <algorithm>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

#include "Syllable.h"
#include "gramambular2/reading_grid.h"

namespace DouJian {

// 候選字：字、佔幾個音、實際查中的讀音（帶聲調，可能為空）、是不是換過鍵修正出來的
struct Candidate {
    std::string value;
    size_t span = 0;
    std::string reading;
    bool corrected = false;
};

// 一串候選，和最前面有幾個是引擎自己的猜測
struct CandidateList {
    std::vector<Candidate> items;
    size_t defaults = 0;

    bool contains(const std::string &value) const {
        return std::any_of(items.begin(), items.end(), [&](const Candidate &c) { return c.value == value; });
    }

    void insert(size_t at, Candidate candidate) {
        items.insert(items.begin() + static_cast<std::ptrdiff_t>(at), std::move(candidate));
    }

    /// 接上其餘的字與詞，已經有的不重複
    void append(const std::vector<Formosa::Gramambular2::ReadingGrid::Candidate> &rest) {
        std::unordered_set<std::string> seen;
        for (const auto &c : items) seen.insert(c.value);
        for (const auto &c : rest) {
            if (seen.insert(c.value).second) items.push_back({c.value, splitUTF8(c.value).size(), c.rawValue});
        }
    }

    /// 依使用者的接續紀錄調整順序：吃掉全部音（span == total）的提到最前面、算引擎猜的；
    /// 只吃前段的排在原本引擎猜的後面。defaults 跟著改成新的「引擎猜的」個數。回傳有沒有整句被提到最前面
    bool promote(const std::vector<std::string> &preferred, size_t total) {
        std::vector<bool> taken(items.size(), false);
        std::vector<Candidate> front;
        std::vector<Candidate> middle;
        for (const auto &word : preferred) {
            for (size_t i = 0; i < items.size(); i++) {
                if (taken[i] || items[i].value != word) continue;
                taken[i] = true;
                (items[i].span == total ? front : middle).push_back(items[i]);
                break;
            }
        }
        if (front.empty() && middle.empty()) return false;
        std::vector<Candidate> out = front;
        size_t keptDefaults = 0;
        for (size_t i = 0; i < defaults && i < items.size(); i++) {
            if (!taken[i]) {
                out.push_back(items[i]);
                keptDefaults++;
            }
        }
        out.insert(out.end(), middle.begin(), middle.end());
        for (size_t i = defaults; i < items.size(); i++) {
            if (!taken[i]) out.push_back(items[i]);
        }
        defaults = front.size() + keptDefaults;
        items.swap(out);
        return !front.empty();
    }

    /// 修正的整句放第 0 個，照打的整句往後移一個。照打的是單一個詞時它不算引擎猜的：
    /// 選回它會被學起來，下次就不會再改
    void putFirst(Candidate corrected, bool typedIsOneWord) {
        for (size_t i = 0; i < items.size(); i++) {
            if (items[i].value != corrected.value) continue;
            items.erase(items.begin() + static_cast<std::ptrdiff_t>(i));
            if (i < defaults) defaults--;
            break;
        }
        insert(0, std::move(corrected));
        defaults = typedIsOneWord ? 1 : 1 + defaults;
    }
};

} // namespace DouJian
