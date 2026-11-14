import SwiftUI

/// 開源授權：每個用到的套件、字型、詞庫的名稱和授權全文。
/// 全文直接讀原始授權檔（project.yml 把它們放進 App 的資源），不另外抄一份；新增套件時在這裡加一列、在 project.yml 加檔
struct LicensesView: View {
    struct Item: Identifiable {
        let name: String
        let license: String
        let file: String

        var id: String {
            file
        }
    }

    static let items = [
        Item(name: "McBopomofo（小麥注音）", license: "MIT License", file: "LICENSE.txt"),
        Item(name: "AOSP LatinIME 英文詞頻表", license: "Apache License 2.0", file: "LICENSE-AOSP-LatinIME.txt"),
        Item(name: "Noto Serif TC", license: "SIL Open Font License 1.1", file: "OFL-NotoSerifTC.txt"),
        Item(name: "霞鶩文楷 TC", license: "SIL Open Font License 1.1", file: "OFL-LXGWWenKaiTC.txt"),
    ]

    var body: some View {
        ScrollView {
            DomySection {
                ForEach(Array(Self.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        DomyDivider()
                    }
                    NavigationLink {
                        LicenseTextView(item: item)
                    } label: {
                        VeggieRow(icon: "doc.text", title: item.name, value: nil, accessory: .push)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.vertical, Gap.s4)
        }
        .background(Brand.theme.canvas)
        .tabBarClearance()
        .navigationTitle(VeggieText.licenses)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 一份授權的全文
private struct LicenseTextView: View {
    let item: LicensesView.Item

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Gap.s3) {
                Text(item.license)
                    .font(Typo.headline.font)
                    .foregroundStyle(Ink.textPrimary)
                Text(fullText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(Ink.textSecondary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.vertical, Gap.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Brand.theme.canvas)
        .tabBarClearance()
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fullText: String {
        let parts = item.file.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let url = Bundle.main.url(forResource: parts[0], withExtension: parts[1]),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return VeggieText.errorGeneric }
        return text
    }
}

/// 蔬菜家族的其他 app：內建清單，點了開 App Store（或網頁）
struct VeggieFamilyView: View {
    var body: some View {
        ScrollView {
            DomySection {
                ForEach(Array(VeggieApp.others.enumerated()), id: \.element.id) { index, app in
                    if index > 0 {
                        DomyDivider()
                    }
                    if let link = app.link {
                        Link(destination: link) {
                            HStack(spacing: Gap.s3) {
                                VStack(alignment: .leading, spacing: Gap.s1 / 2) {
                                    Text(app.name)
                                        .font(Typo.headline.font)
                                        .foregroundStyle(Ink.textPrimary)
                                    Text(app.tagline)
                                        .font(Typo.subheadline.font)
                                        .foregroundStyle(Ink.textSecondary)
                                }
                                Spacer()
                                Text("取得")
                                    .font(Typo.callout.font)
                                    .foregroundStyle(Brand.theme.strong)
                            }
                            .frame(minHeight: Metric.row)
                        }
                    }
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.vertical, Gap.s4)
        }
        .background(Brand.theme.canvas)
        .tabBarClearance()
        .navigationTitle(VeggieText.family)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 使用說明（從設定頁「支援」點進來）
struct GuidePage: View {
    var body: some View {
        ScrollView {
            GuideView()
                .padding(.horizontal, Metric.screenMargin)
                .padding(.vertical, Gap.s4)
        }
        .background(Brand.theme.canvas)
        .tabBarClearance()
        .navigationTitle("使用說明")
        .navigationBarTitleDisplayMode(.inline)
    }
}
