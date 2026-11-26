#import "BopomofoEngine.h"

#include <algorithm>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "AssociatedPhrasesV2.h"
#include "ComposingSession.h"
#include "Syllable.h"

// 組字、候選、簡拼、鄰鍵容錯都在 ComposingSession（純 C++，Windows 上能編來測）；這裡只做型別轉換
@implementation BopomofoEngine {
    std::unique_ptr<DouJian::ComposingSession> _session;
    std::unique_ptr<McBopomofo::AssociatedPhrasesV2> _associated;
    // Swift 每鍵會讀好幾次 candidates、composing：轉好的留著，組字或候選可能變了（invalidateCache）才重轉
    NSArray<NSString *> *_cachedCandidates;
    NSString *_cachedComposing;
}

- (nullable instancetype)initWithDataPath:(NSString *)dataPath associatedPath:(nullable NSString *)associatedPath {
    self = [super init];
    if (!self) return nil;
    _session = std::make_unique<DouJian::ComposingSession>();
    if (!_session->open(dataPath.fileSystemRepresentation)) return nil;
    if (associatedPath) {
        _associated = std::make_unique<McBopomofo::AssociatedPhrasesV2>();
        if (!_associated->open(associatedPath.fileSystemRepresentation)) _associated.reset();
    }
    return self;
}

// MARK: - 公開接口

- (BOOL)feedSymbol:(NSString *)symbol {
    return [self feedSymbol:symbol alternatives:@[] costs:@[]];
}

- (BOOL)feedSymbol:(NSString *)symbol
      alternatives:(NSArray<NSString *> *)alternatives
             costs:(NSArray<NSNumber *> *)costs {
    [self invalidateCache];
    DouJian::ComposingSession::Alternatives list;
    NSUInteger n = MIN(alternatives.count, costs.count);
    for (NSUInteger i = 0; i < n; i++) {
        list.emplace_back(std::string(alternatives[i].UTF8String), costs[i].doubleValue);
    }
    return _session->feed(std::string(symbol.UTF8String), list) ? YES : NO;
}

- (BOOL)canSealFirstTone {
    return _session->canSealFirstTone() ? YES : NO;
}

- (void)sealFirstTone {
    [self invalidateCache];
    _session->sealFirstTone();
}

- (NSString *)composing {
    if (!_cachedComposing) _cachedComposing = [NSString stringWithUTF8String:_session->composing().c_str()];
    return _cachedComposing;
}

- (NSInteger)composingStage {
    return _session->composingStage();
}

- (NSArray<NSString *> *)candidates {
    if (_cachedCandidates) return _cachedCandidates;
    const auto &list = _session->candidates();
    NSMutableArray<NSString *> *out = [NSMutableArray arrayWithCapacity:list.size()];
    for (const auto &c : list) {
        [out addObject:[NSString stringWithUTF8String:c.value.c_str()]];
    }
    // 存不可變的：Swift 每次轉成 [String] 只要 retain，不用整串複製
    _cachedCandidates = [out copy];
    return _cachedCandidates;
}

- (NSArray<NSNumber *> *)correctedIndexes {
    const auto &list = _session->candidates();
    NSMutableArray<NSNumber *> *out = [NSMutableArray array];
    for (size_t i = 0; i < list.size(); i++) {
        if (list[i].corrected) [out addObject:@(i)];
    }
    return out;
}

- (NSUInteger)defaultCandidateCount {
    return _session->defaultCount();
}

- (NSString *)selectCandidateAtIndex:(NSUInteger)index {
    [self invalidateCache];
    return [NSString stringWithUTF8String:_session->select(index).c_str()];
}

- (NSString *)lastSelectedReading {
    return [NSString stringWithUTF8String:_session->lastSelectedReading().c_str()];
}

- (BOOL)backspace {
    [self invalidateCache];
    return _session->backspace() ? YES : NO;
}

- (void)clear {
    [self invalidateCache];
    _session->clear();
}

- (NSArray<NSString *> *)associatedPhrasesAfter:(NSString *)text {
    if (!_associated || text.length == 0) return @[];
    // 用最後一個字查（聯想詞庫的 key 是「字-讀音-字-讀音…」，只給字就是比對所有讀音）
    auto chars = DouJian::splitUTF8(text.UTF8String);
    if (chars.empty()) return @[];
    const std::string &last = chars.back();
    auto phrases = _associated->findPhrases(last, {});
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (const auto &p : phrases) {
        if (p.value.size() <= last.size() || p.value.compare(0, last.size(), last) != 0) continue;
        NSString *rest = [NSString stringWithUTF8String:p.value.substr(last.size()).c_str()];
        if (rest.length == 0 || [seen containsObject:rest]) continue;
        [seen addObject:rest];
        [out addObject:rest];
        if (out.count >= 40) break;
    }
    return out;
}

- (void)setUserPhrasesWithReadings:(NSArray<NSString *> *)readings words:(NSArray<NSString *> *)words {
    [self invalidateCache];
    DouJian::UserPhrases phrases;
    NSUInteger n = MIN(readings.count, words.count);
    for (NSUInteger i = 0; i < n; i++) {
        auto &list = phrases[std::string(readings[i].UTF8String)];
        // 分數 0 比詞庫裡任何詞都高（詞庫是負的對數機率）；同讀音照陣列順序微幅遞減，先後才固定
        list.emplace_back(std::string(words[i].UTF8String), -0.0001 * static_cast<double>(list.size()));
    }
    _session->setUserPhrases(std::move(phrases));
}

- (void)setPreferredFollowers:(NSArray<NSString *> *)words {
    [self invalidateCache];
    std::vector<std::string> list;
    for (NSString *w in words) list.emplace_back(w.UTF8String);
    _session->setPreferred(std::move(list));
}

// MARK: - 快取

/// 會動到組字或候選的方法一開頭都要叫：feedSymbol、sealFirstTone、selectCandidateAtIndex、backspace、clear、
/// setUserPhrases、setPreferredFollowers
- (void)invalidateCache {
    _cachedCandidates = nil;
    _cachedComposing = nil;
}

@end
