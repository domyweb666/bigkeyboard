#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Swift 與小麥注音 C++ 引擎之間唯一的接口。畫面層只准碰這個類別。
@interface BopomofoEngine : NSObject

/// dataPath：小麥詞庫 data.txt 的路徑；associatedPath：聯想詞庫（可為 nil）。主詞庫載入失敗回傳 nil。
- (nullable instancetype)initWithDataPath:(NSString *)dataPath associatedPath:(nullable NSString *)associatedPath;

/// 送一個注音符號（如「ㄋ」「ˇ」）進組字器。回傳 NO 表示這個符號接不上目前的注音、已被忽略。
- (BOOL)feedSymbol:(NSString *)symbol;

/// 目前正在組、尚未送出的注音（如「ㄋㄧˇ ㄏㄠˇ」，音與音之間空一格）。空字串表示沒有在組。
@property (nonatomic, readonly) NSString *composing;

/// 正在打的那個音打到哪一段：0 沒在打、1 只有聲母、2 到介音、3 到韻母（打了聲調就收進格子，回到 0）
@property (nonatomic, readonly) NSInteger composingStage;

/// 目前注音對應的候選字，依機率高到低。沒在組字時為空陣列。
@property (nonatomic, readonly) NSArray<NSString *> *candidates;

/// 候選最前面有幾個是引擎自己的猜測（整句、整句的第一段）。選這幾個不算改過候選，自動學詞要用。
@property (nonatomic, readonly) NSUInteger defaultCandidateCount;

/// 選第 index 個候選字：回傳要送進輸入框的字，並清空組字狀態。index 越界回傳空字串。
- (NSString *)selectCandidateAtIndex:(NSUInteger)index;

/// 刪最後一個注音符號。回傳 NO 表示本來就沒有在組字（呼叫端應改成刪輸入框的字）。
- (BOOL)backspace;

- (void)clear;

/// 剛送出 text 之後可以接的字詞（聯想詞），依機率高到低，已去掉 text 本身。沒有則空陣列。
- (NSArray<NSString *> *)associatedPhrasesAfter:(NSString *)text;

/// 使用者字典的詞：readings[i] 讀成 words[i]（讀音用小麥詞庫的格式，音節以 - 連接）。
/// 這些詞排在同讀音候選的最前面，整句組字也優先用；同讀音時照陣列順序排。
- (void)setUserPhrasesWithReadings:(NSArray<NSString *> *)readings
                             words:(NSArray<NSString *> *)words NS_SWIFT_NAME(setUserPhrases(readings:words:));

/// 使用者自己打過、常接在游標前那段字後面的字詞（常用的在前）。候選裡有它們就往前排：
/// 吃掉全部注音的排到最前面（算引擎猜的），只吃前段的排在引擎猜的後面。正在組字時會馬上重排。
- (void)setPreferredFollowers:(NSArray<NSString *> *)words NS_SWIFT_NAME(setPreferredFollowers(_:));

/// 上一次 selectCandidateAtIndex: 選走的那幾個音（帶聲調、小麥格式），給自動學詞用。沒選過時為空字串。
@property (nonatomic, readonly) NSString *lastSelectedReading;

@end

NS_ASSUME_NONNULL_END
