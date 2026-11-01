#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Swift 與小麥注音 C++ 引擎之間唯一的接口。畫面層只准碰這個類別。
@interface BopomofoEngine : NSObject

/// dataPath：小麥詞庫 data.txt 的路徑；associatedPath：聯想詞庫（可為 nil）。主詞庫載入失敗回傳 nil。
- (nullable instancetype)initWithDataPath:(NSString *)dataPath associatedPath:(nullable NSString *)associatedPath;

/// 送一個注音符號（如「ㄋ」「ˇ」）進組字器。回傳 NO 表示這個符號接不上目前的注音、已被忽略。
- (BOOL)feedSymbol:(NSString *)symbol;

/// 目前正在組、尚未送出的注音（如「ㄋㄧˇ」）。空字串表示沒有在組。
@property (nonatomic, readonly) NSString *composing;

/// 目前注音對應的候選字，依機率高到低。沒在組字時為空陣列。
@property (nonatomic, readonly) NSArray<NSString *> *candidates;

/// 選第 index 個候選字：回傳要送進輸入框的字，並清空組字狀態。index 越界回傳空字串。
- (NSString *)selectCandidateAtIndex:(NSUInteger)index;

/// 刪最後一個注音符號。回傳 NO 表示本來就沒有在組字（呼叫端應改成刪輸入框的字）。
- (BOOL)backspace;

- (void)clear;

/// 剛送出 text 之後可以接的字詞（聯想詞），依機率高到低，已去掉 text 本身。沒有則空陣列。
- (NSArray<NSString *> *)associatedPhrasesAfter:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
