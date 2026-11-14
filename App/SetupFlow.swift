import SwiftUI

/// 首次打開的設定流程：格 1 加入鍵盤 → 格 2 試打。只有新安裝會跳，從舊版更新上來的不跳；
/// 中途把 App 關掉，重開還會跳。設計見 .uiux/06-首次體驗-暫定.md
@MainActor
enum SetupFlow {
    /// false：還沒走完；true：走完或略過。從舊版更新上來的人沒有這筆
    private static let doneKey = "setup.v1.done"
    /// 1.0 就有記的「第一次打開」日期：沒有它代表新安裝
    private static let firstOpenKey = "review.firstOpen"

    /// App 啟動時呼叫，要在 ReviewPrompt.recordLaunch() 之前（才分得出新安裝和更新）
    static func prepare() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: firstOpenKey) == nil, defaults.object(forKey: doneKey) == nil {
            defaults.set(false, forKey: doneKey)
        }
    }

    /// 這次打開要不要跳設定流程
    static var isPending: Bool {
        UserDefaults.standard.object(forKey: doneKey) as? Bool == false
    }

    static func finish() {
        UserDefaults.standard.set(true, forKey: doneKey)
    }
}

/// 設定流程的畫面。吉祥物：格 1 先揮手再指向按鈕，格 2 指向輸入框，打出中文字時慶祝
struct SetupFlowView: View {
    enum Step: String {
        case addKeyboard
        case tryTyping
    }

    let onFinish: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("setup.v1.step") private var step = Step.addKeyboard
    /// 按過「前往設定」：回到前景（或在設定時 App 被關掉、重開）就進格 2
    @AppStorage("setup.v1.wentToSettings") private var wentToSettings = false
    @State private var mascot = MascotView.Action.wave
    @State private var typed = ""
    @FocusState private var fieldFocused: Bool

    private static let mascotHeight: CGFloat = 220
    private static let mascotHeightTyping: CGFloat = 150
    /// 格 1 揮手多久再轉去指按鈕（秒）
    private static let waveSeconds = 1.5

    var body: some View {
        VStack(spacing: 0) {
            skipBar
            ScrollView {
                Group {
                    switch step {
                    case .addKeyboard: addKeyboard
                    case .tryTyping: tryTyping
                    }
                }
                .padding(.horizontal, Metric.screenMargin)
                .padding(.bottom, Gap.s6)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Brand.theme.canvas)
        .onAppear(perform: returnFromSettings)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                returnFromSettings()
            }
        }
        .task(id: step) {
            await stepStarted()
        }
        .onChange(of: typedChinese) {
            mascot = typedChinese ? .cheer : .pointDown
        }
        .sensoryFeedback(.success, trigger: typedChinese) { old, new in
            !old && new
        }
    }

    private var skipBar: some View {
        HStack {
            Spacer()
            Button("略過", action: finish)
                .font(Typo.callout.font)
                .foregroundStyle(Ink.textSecondary)
                .frame(minWidth: Metric.touch, minHeight: Metric.touch)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Metric.screenMargin)
    }

    private var addKeyboard: some View {
        VStack(spacing: Gap.s6) {
            MascotView(action: mascot)
                .frame(height: Self.mascotHeight)
            VStack(alignment: .leading, spacing: Gap.s4) {
                title("先把豆鍵加進鍵盤")
                number(1, "按「前往設定」")
                number(2, "點「鍵盤」")
                number(3, "打開「豆鍵」")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: Gap.s2) {
                Button("前往設定") {
                    wentToSettings = true
                    AppSettings.open()
                }
                .buttonStyle(DomyButtonStyle())
                textButton("已經加好了") {
                    go(.tryTyping)
                }
            }
        }
    }

    private var tryTyping: some View {
        VStack(spacing: Gap.s5) {
            MascotView(action: mascot)
                .frame(height: Self.mascotHeightTyping)
            VStack(alignment: .leading, spacing: Gap.s2) {
                title(typedChinese ? "打出來了" : "切到豆鍵，打一個字")
                Text(typedChinese ? Self.doneDetail : "按鍵盤左下角的地球鍵，換到豆鍵。")
                    .font(Typo.subheadline.font)
                    .foregroundStyle(Ink.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TextField("在這裡打字", text: $typed)
                .focused($fieldFocused)
                .font(Typo.body.font)
                .padding(.horizontal, Gap.s4)
                .frame(minHeight: Metric.field)
                .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.xl))
                .overlay {
                    RoundedRectangle(cornerRadius: Corner.xl)
                        .stroke(Ink.fieldBorder, lineWidth: Metric.hairline)
                }
            if typedChinese {
                Button("開始用", action: finish)
                    .buttonStyle(DomyButtonStyle())
            } else {
                textButton("還沒看到豆鍵？") {
                    wentToSettings = false
                    go(.addKeyboard)
                }
            }
        }
    }

    private static let doneDetail = "之後在任何 App 打字，按地球鍵就能換到豆鍵。需要幫忙時，到設定 → 使用說明。"

    /// 輸入框裡有中文字就算打出來了。分不出是不是豆鍵打的（系統注音也會過），組字中的注音符號不算
    private var typedChinese: Bool {
        typed.unicodeScalars.contains { (0x3400 ... 0x9FFF).contains($0.value) }
    }

    private func returnFromSettings() {
        if wentToSettings, step == .addKeyboard {
            go(.tryTyping)
        }
    }

    private func go(_ next: Step) {
        withAnimation(.easeOut(duration: DomyTokens.Motion.transition)) {
            step = next
        }
    }

    /// 每換一格：格 1 揮手後轉去指按鈕；格 2 指輸入框，等畫面換好再叫出鍵盤
    private func stepStarted() async {
        switch step {
        case .addKeyboard:
            fieldFocused = false
            mascot = .wave
            do {
                try await Task.sleep(for: .seconds(Self.waveSeconds))
            } catch {
                return
            }
            mascot = .pointDown
        case .tryTyping:
            mascot = typedChinese ? .cheer : .pointDown
            do {
                try await Task.sleep(for: .seconds(DomyTokens.Motion.transition))
            } catch {
                return
            }
            fieldFocused = true
        }
    }

    private func finish() {
        fieldFocused = false
        wentToSettings = false
        step = .addKeyboard
        SetupFlow.finish()
        onFinish()
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(Typo.title2.font)
            .foregroundStyle(Ink.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    /// 一步：實心圓圈數字＋說明（跟使用說明「開始用豆鍵」同款）
    private func number(_ number: Int, _ text: String) -> some View {
        HStack(spacing: Gap.s3) {
            Text("\(number)")
                .font(Typo.subheadline.font.weight(.bold))
                .foregroundStyle(Brand.theme.onAccent)
                .frame(width: Gap.s8 - Gap.s1 / 2, height: Gap.s8 - Gap.s1 / 2)
                .background(Brand.theme.accent, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(Typo.body.font)
                .foregroundStyle(Ink.textPrimary)
        }
    }

    private func textButton(_ text: String, action: @escaping () -> Void) -> some View {
        Button(text, action: action)
            .font(Typo.callout.font)
            .foregroundStyle(Brand.theme.strong)
            .frame(maxWidth: .infinity, minHeight: Metric.touch)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }
}
