import SwiftUI
import UIKit

/// 最下面再放一次 logo、版本號、網站和社群連結（參考 minical 的設定頁）；長按版本號複製診斷資訊
struct VeggieFooter: View {
    /// 上方跳提示（設定頁的）
    let show: (String) -> Void

    var body: some View {
        VStack(spacing: Gap.s3) {
            Image("AppLogo")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(spacing: Gap.s1) {
                Text(VeggieConfig.current.versionLine)
                    .font(Typo.subheadline.font)
                    .foregroundStyle(Ink.textSecondary)
                Text(VeggieText.madeBy)
                    .font(Typo.footnote.font)
                    .foregroundStyle(Ink.textTertiary)
            }
            .contentShape(Rectangle())
            .onLongPressGesture {
                UIPasteboard.general.string = Feedback.diagnostics
                show(VeggieText.diagnosticsCopied)
            }
            .accessibilityHint("長按複製版本資訊")
            HStack(spacing: Gap.s4) {
                ForEach(VeggieConfig.current.links) { link in
                    if let url = link.url {
                        Link(destination: url) {
                            linkIcon(link.kind)
                                .frame(width: Metric.touch, height: Metric.touch)
                        }
                        .accessibilityLabel(link.label)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Gap.s6)
    }

    @ViewBuilder private func linkIcon(_ kind: VeggieLink.Kind) -> some View {
        switch kind {
        case .website:
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(Ink.textSecondary)
        case .facebook:
            brandIcon("Facebook")
        case .instagram:
            brandIcon("Instagram")
        }
    }

    private func brandIcon(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .foregroundStyle(Ink.textSecondary)
    }
}
