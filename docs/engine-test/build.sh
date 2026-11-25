cd "$(dirname "$0")"
mkdir -p hdr real vendor
cp -r /e/豆鍵/KeyboardExtension/Engine/Vendor/McBopomofo/. vendor/
# MSVC string_view iterator is not a raw pointer (scratch copy only)
sed -i 's/const auto\* it /auto it /; s/const auto\* value_begin/auto value_begin/' vendor/ParselessLM.cpp
cp /e/豆鍵/KeyboardExtension/Engine/Bridge/*.h real/
cp real/*.h hdr/
sed -i 's/static constexpr double \(last\|consonant\|syllabic\|syllabicInAbbreviation\|nearMargin\|singleMaxCost\|kTouchedUserScore\)/static inline double \1/' hdr/*.h
cmd //c ".\build.bat $1" 2>&1 | grep -a "error\|warning C\|fatal" | head -20
