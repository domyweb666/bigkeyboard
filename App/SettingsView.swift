import SwiftUI
import UIKit

/// 設定：照《蔬菜家族 App 共用基本元素規格》的標準結構排——
/// 豆鍵自己的（空白鍵）→ 一般 → 資料（DataSettingsSection）→ 購買 → 支援 → 關於 → 版本頁尾。
/// 值沒填（VeggieConfig 是 nil）的那一列整列隱藏
struct SettingsView: View {
    @AppStorage(SpaceKeySetting.storageKey, store: SpaceKeySetting.defaults)
    private var spaceSelectsFirstCandidate = false
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @Environment(\.openURL) private var openURL

    @State private var restoring = false
    @State private var showMail = false
    @State private var toast: String?

    private let config = VeggieConfig.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Gap.s6) {
                    DomyTitle("設定")
                    spaceSection
                    generalSection
                    DataSettingsSection(
                        spaceSelectsFirstCandidate: $spaceSelectsFirstCandidate,
                        appearance: $appearance,
                        show: show
                    )
                    purchaseSection
                    supportSection
                    aboutSection
                    versionFooter
                }
                .padding(.horizontal, Metric.screenMargin)
                .padding(.top, Gap.s2)
            }
            .background(Brand.theme.canvas)
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(Typo.callout.font)
                    .foregroundStyle(Ink.textPrimary)
                    .padding(.horizontal, Gap.s4)
                    .padding(.vertical, Gap.s2)
                    .background(Ink.surface, in: Capsule())
                    .domyShadow(DomyTokens.Elevation.level2)
                    .padding(.top, Gap.s2)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 豆鍵自己的

    private var spaceSection: some View {
        DomySection("空白鍵", footer: spaceFooter) {
            VeggieToggleRow(icon: "space", title: "空白鍵直接選第一個字", isOn: $spaceSelectsFirstCandidate)
        }
    }

    private var spaceFooter: String {
        let behavior = spaceSelectsFirstCandidate
            ? "打 ㄉㄧ 按空白，直接送出候選列第一個字。"
            : "打 ㄉㄧ 按空白，先定成一聲，候選只剩 低、滴 這些一聲字，再按一下空白送出。"
            + "打了聲調的音，按一下空白就送出。"
        return behavior + "\n要打開「允許完全取用」，鍵盤才讀得到這個設定；沒打開時空白鍵是當一聲。"
    }

    // MARK: - 一般

    private var generalSection: some View {
        DomySection("一般") {
            Menu {
                Picker(VeggieText.appearance, selection: $appearance) {
                    ForEach(Appearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                VeggieRow(
                    icon: "circle.lefthalf.filled",
                    title: VeggieText.appearance,
                    value: appearance.title,
                    accessory: .push
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 購買

    private var purchaseSection: some View {
        DomySection("購買") {
            Button {
                Task { await restore() }
            } label: {
                VeggieRow(icon: "arrow.clockwise", title: VeggieText.restore, value: restoring ? "恢復中…" : nil)
            }
            .buttonStyle(.plain)
            .disabled(restoring)
        }
    }

    private func restore() async {
        restoring = true
        let owned = await ThemePurchases.restore()
        restoring = false
        switch owned {
        case .none:
            show(VeggieText.errorGeneric)
        case let .some(set) where set.isEmpty:
            show(VeggieText.restoreNone)
        case .some:
            show(VeggieText.restoreSuccess)
        }
    }

    // MARK: - 支援

    private var supportSection: some View {
        DomySection("支援") {
            NavigationLink {
                GuidePage()
            } label: {
                VeggieRow(icon: "questionmark.circle", title: "使用說明", accessory: .push)
            }
            .buttonStyle(.plain)
            if let email = config.supportEmail {
                DomyDivider()
                Button {
                    if Feedback.canUseMailSheet {
                        showMail = true
                    } else if let url = Feedback.mailtoURL(to: email) {
                        openURL(url)
                    }
                } label: {
                    VeggieRow(icon: "envelope", title: VeggieText.feedback, accessory: .push)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showMail) {
                    FeedbackMailView(recipient: email) { showMail = false }
                }
            }
            if let url = config.writeReviewURL {
                DomyDivider()
                Link(destination: url) {
                    VeggieRow(icon: "star", title: VeggieText.rate, accessory: .external)
                }
                .buttonStyle(.plain)
            }
            if let url = config.appStoreURL {
                DomyDivider()
                ShareLink(item: url, message: Text("我在用\(config.name)：\(config.tagline)")) {
                    VeggieRow(icon: "square.and.arrow.up.on.square", title: VeggieText.share, accessory: .external)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 關於

    private var aboutSection: some View {
        DomySection("關於") {
            if !VeggieApp.others.isEmpty {
                NavigationLink {
                    VeggieFamilyView()
                } label: {
                    VeggieRow(icon: "leaf", title: VeggieText.family, accessory: .push)
                }
                .buttonStyle(.plain)
                DomyDivider()
            }
            if let url = config.privacyURL {
                Link(destination: url) {
                    VeggieRow(icon: "hand.raised", title: VeggieText.privacy, accessory: .external)
                }
                .buttonStyle(.plain)
                DomyDivider()
            }
            NavigationLink {
                LicensesView()
            } label: {
                VeggieRow(icon: "doc.text", title: VeggieText.licenses, accessory: .push)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 頁尾

    /// 「豆鍵 1.0 (73)」＋「Made by DOMYWEB」；長按複製診斷資訊
    private var versionFooter: some View {
        VStack(spacing: Gap.s1) {
            Text(config.versionLine)
            Text(VeggieText.madeBy)
        }
        .font(Typo.footnote.font)
        .foregroundStyle(Ink.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Gap.s4)
        .contentShape(Rectangle())
        .onLongPressGesture {
            UIPasteboard.general.string = Feedback.diagnostics
            show(VeggieText.diagnosticsCopied)
        }
        .accessibilityHint("長按複製版本資訊")
    }

    // MARK: - 小工具

    /// 上方跳一下提示，兩秒後收起
    private func show(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                if toast == text {
                    toast = nil
                }
            }
        }
    }
}
