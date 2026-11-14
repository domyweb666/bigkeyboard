import MessageUI
import SwiftUI
import UIKit

/// 意見回饋與版本資訊：信的主旨「[豆鍵] 意見回饋」，內文最下面帶診斷資訊（使用者看得到、可以刪）
@MainActor
enum Feedback {
    static var subject: String {
        "[\(VeggieConfig.current.name)] 意見回饋"
    }

    static var body: String {
        "（請在這裡寫下你的想法）\n\n\n\n——\n" + diagnostics
    }

    /// 版本頁尾長按複製的也是這段
    static var diagnostics: String {
        [
            "App：\(VeggieConfig.current.versionLine)",
            "iOS：\(UIDevice.current.systemVersion)",
            "機型：\(machine)",
            "語言：\(Locale.preferredLanguages.first ?? "")",
        ].joined(separator: "\n")
    }

    /// 機型代號，例如 iPhone17,1（不另外對照成 iPhone 16 Pro 這種名字，新機一出就要改表）
    private static var machine: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    static var canUseMailSheet: Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// 手機沒設郵件帳號時改用 mailto（交給使用者裝的其他寄信 app）
    static func mailtoURL(to address: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = address
        parts.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return parts.url
    }
}

/// 系統寫信畫面
struct FeedbackMailView: UIViewControllerRepresentable {
    let recipient: String
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients([recipient])
        mail.setSubject(Feedback.subject)
        mail.setMessageBody(Feedback.body, isHTML: false)
        return mail
    }

    func updateUIViewController(_: MFMailComposeViewController, context _: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func mailComposeController(
            _: MFMailComposeViewController,
            didFinishWith _: MFMailComposeResult,
            error _: Error?
        ) {
            onDone()
        }
    }
}
