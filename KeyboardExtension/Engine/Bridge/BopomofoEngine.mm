#import "BopomofoEngine.h"

#include <memory>
#include <string>
#include <vector>

#include "Mandarin/Mandarin.h"
#include "ParselessLM.h"
#include "gramambular2/reading_grid.h"

using Formosa::Mandarin::BopomofoKeyboardLayout;
using Formosa::Mandarin::BopomofoReadingBuffer;
using Formosa::Mandarin::BPMF;

@implementation BopomofoEngine {
    std::shared_ptr<McBopomofo::ParselessLM> _lm;
    std::unique_ptr<BopomofoReadingBuffer> _buffer;
    std::unique_ptr<Formosa::Gramambular2::ReadingGrid> _grid;
}

- (nullable instancetype)initWithDataPath:(NSString *)dataPath {
    self = [super init];
    if (!self) return nil;
    _lm = std::make_shared<McBopomofo::ParselessLM>();
    if (!_lm->open(dataPath.fileSystemRepresentation)) return nil;
    _buffer = std::make_unique<BopomofoReadingBuffer>(BopomofoKeyboardLayout::StandardLayout());
    _grid = std::make_unique<Formosa::Gramambular2::ReadingGrid>(_lm);
    return self;
}

- (BOOL)feedSymbol:(NSString *)symbol {
    // 符號 → 它的 component → 標準注音鍵位的 ASCII 鍵 → 組字器。合法性判斷走小麥原本的路。
    BPMF parsed = BPMF::FromComposedString(symbol.UTF8String);
    if (parsed.isEmpty()) return NO;
    BPMF::Component component = 0;
    if (parsed.hasConsonant()) component = parsed.consonantComponent();
    else if (parsed.hasMiddleVowel()) component = parsed.middleVowelComponent();
    else if (parsed.hasVowel()) component = parsed.vowelComponent();
    else if (parsed.hasToneMarker()) component = parsed.toneMarkerComponent();
    char key = BopomofoKeyboardLayout::StandardLayout()->componentToKey(component);
    if (!key) return NO;
    return _buffer->combineKey(key);
}

- (NSString *)composing {
    return [NSString stringWithUTF8String:_buffer->composedString().c_str()];
}

- (NSArray<NSString *> *)candidates {
    if (_buffer->isEmpty()) return @[];
    std::string reading = _buffer->syllable().composedString();
    auto unigrams = _lm->getUnigrams(reading);
    NSMutableArray<NSString *> *out = [NSMutableArray arrayWithCapacity:unigrams.size()];
    for (const auto &u : unigrams) {
        [out addObject:[NSString stringWithUTF8String:u.value().c_str()]];
    }
    return out;
}

- (NSString *)selectCandidateAtIndex:(NSUInteger)index {
    NSArray<NSString *> *list = self.candidates;
    if (index >= list.count) return @"";
    NSString *picked = list[index];
    [self clear];
    return picked;
}

- (BOOL)backspace {
    if (_buffer->isEmpty()) return NO;
    _buffer->backspace();
    return YES;
}

- (void)clear {
    _buffer->clear();
    _grid->clear();
}

@end
