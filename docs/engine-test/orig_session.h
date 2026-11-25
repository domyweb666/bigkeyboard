#pragma once
// 改之前的 BopomofoEngine.mm 的 ObjC 方法，逐行改寫成 C++（core 是直接抽的）
#include "orig_core.h"
namespace orig {
class Session {
public:
    std::shared_ptr<McBopomofo::ParselessLM> _lm;
    std::shared_ptr<FuzzyToneLM> _toneLM;
    std::unique_ptr<BopomofoReadingBuffer> _buffer;
    std::unique_ptr<ReadingGrid> _grid;
    std::vector<CachedCandidate> _candidateCache;
    std::string _lastSelectedReading;
    NSUInteger _defaultCandidateCount = 0;
    std::vector<std::string> _preferred;

    bool open(const char *path) {
        _lm = std::make_shared<McBopomofo::ParselessLM>();
        if (!_lm->open(path)) return false;
        _buffer = std::make_unique<BopomofoReadingBuffer>(BopomofoKeyboardLayout::StandardLayout());
        _toneLM = std::make_shared<FuzzyToneLM>(_lm, path);
        _grid = std::make_unique<ReadingGrid>(_toneLM);
        return true;
    }
    void pushBufferIntoGrid() {
        if (_buffer->isEmpty()) return;
        _grid->setCursor(_grid->length());
        _grid->insertReading(_buffer->syllable().composedString());
        _buffer->clear();
    }
    void rebuildCandidates() {
        _candidateCache.clear();
        _defaultCandidateCount = 0;
        bool tentative = !_buffer->isEmpty();
        if (tentative) {
            _grid->setCursor(_grid->length());
            _grid->insertReading(_buffer->syllable().composedString());
        }
        if (_grid->length() == 0) return;
        auto walk = _grid->walk();
        if (walk.nodes.size() >= 2) {
            std::string value;
            std::string reading;
            for (const auto &n : walk.nodes) {
                value += n->value();
                if (!reading.empty()) reading += "-";
                reading += n->currentUnigram().rawValue();
            }
            _candidateCache.push_back({value, _grid->length(), reading});
        }
        if (!walk.nodes.empty()) {
            const auto &n = walk.nodes.front();
            _candidateCache.push_back({n->value(), n->spanningLength(), n->currentUnigram().rawValue()});
        }
        _defaultCandidateCount = _candidateCache.size();
        for (const auto &c : _grid->candidatesAt(0)) {
            size_t span = splitUTF8(c.value).size();
            bool dup = false;
            for (const auto &e : _candidateCache) if (e.value == c.value) { dup = true; break; }
            if (!dup) _candidateCache.push_back({c.value, span, c.rawValue});
        }
        promotePreferred(_candidateCache, _defaultCandidateCount, _preferred, _grid->length());
        if (tentative) {
            _grid->setCursor(_grid->length());
            _grid->deleteReadingBeforeCursor();
        }
    }
    bool feed(const std::string &symbol) {
        char key = keyForSymbol(symbol);
        if (!key) return false;
        BPMF incoming = BPMF::FromComposedString(symbol);
        BPMF current = _buffer->syllable();
        bool startNew = stage(incoming) <= stage(current);
        if (!startNew && !current.isEmpty() && !incoming.hasToneMarker()) {
            BPMF joined = current;
            joined += incoming;
            startNew = !_toneLM->isSyllableStart(joined.composedString());
        }
        if (startNew) pushBufferIntoGrid();
        bool ok = _buffer->combineKey(key);
        if (_buffer->syllable().hasToneMarker()) pushBufferIntoGrid();
        rebuildCandidates();
        return ok;
    }
    bool canSealFirstTone() {
        if (_buffer->isEmpty() || _buffer->syllable().hasToneMarker()) return false;
        for (const auto &r : _grid->readings()) if (!hasToneMark(r)) return false;
        return _toneLM->hasUnigrams(_buffer->syllable().composedString() + kToneOneMark);
    }
    void sealFirstTone() {
        if (!canSealFirstTone()) return;
        _grid->setCursor(_grid->length());
        _grid->insertReading(_buffer->syllable().composedString() + kToneOneMark);
        _buffer->clear();
        rebuildCandidates();
    }
    std::string composing() const {
        std::string s;
        for (const auto &r : _grid->readings()) { if (!s.empty()) s += " "; s += r; }
        if (!_buffer->isEmpty()) { if (!s.empty()) s += " "; s += _buffer->composedString(); }
        return s;
    }
    int composingStage() const { return stage(_buffer->syllable()); }
    std::string select(size_t index) {
        if (index >= _candidateCache.size()) return "";
        auto picked = _candidateCache[index];
        pushBufferIntoGrid();
        size_t span = std::min(picked.span, _grid->length());
        if (!picked.reading.empty()) _lastSelectedReading = picked.reading;
        else {
            auto readings = _grid->readings();
            std::string joined;
            for (size_t i = 0; i < span && i < readings.size(); i++) { if (i > 0) joined += "-"; joined += readings[i]; }
            _lastSelectedReading = withoutToneOneMark(joined);
        }
        _grid->setCursor(span);
        for (size_t i = 0; i < span; i++) _grid->deleteReadingBeforeCursor();
        _grid->setCursor(_grid->length());
        rebuildCandidates();
        return picked.value;
    }
    bool backspace() {
        if (!_buffer->isEmpty()) {
            _buffer->backspace();
        } else if (_grid->length() > 0) {
            std::string last = _grid->readings().back();
            _grid->setCursor(_grid->length());
            _grid->deleteReadingBeforeCursor();
            for (const auto &ch : splitUTF8(last)) { char k = keyForSymbol(ch); if (k) _buffer->combineKey(k); }
            if (!isSealedToneOne(last)) _buffer->backspace();
        } else return false;
        reopen();
        rebuildCandidates();
        return true;
    }
    void reopen() {
        if (!_buffer->isEmpty() || _grid->length() == 0) return;
        std::string last = _grid->readings().back();
        if (hasToneMark(last)) return;
        _grid->setCursor(_grid->length());
        _grid->deleteReadingBeforeCursor();
        for (const auto &ch : splitUTF8(last)) { char k = keyForSymbol(ch); if (k) _buffer->combineKey(k); }
    }
    void clear() { _buffer->clear(); _grid->clear(); _candidateCache.clear(); }
    void setUserPhrases(const std::vector<std::pair<std::string, std::string>> &list) {
        std::map<std::string, std::vector<Unigram>> phrases;
        for (auto &[r, w] : list) { auto &l = phrases[r]; l.emplace_back(w, -0.0001 * static_cast<double>(l.size())); }
        _toneLM->setUserPhrases(std::move(phrases));
    }
    void setPreferred(std::vector<std::string> w) {
        _preferred = std::move(w);
        if (_grid->length() > 0 || !_buffer->isEmpty()) rebuildCandidates();
    }
};
} // namespace orig
