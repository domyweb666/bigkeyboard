import UIKit

/// 鍵盤最上面中間的拖曳條：從頂端往下滑就收起鍵盤（有些 app 沒地方收鍵盤，鍵盤又大，關不掉很麻煩）
extension KeyboardViewController: UIGestureRecognizerDelegate {
    /// 往下滑超過這個距離才收，太短容易誤觸
    private static let dismissDistance: CGFloat = 30
    /// 沒有候選列的鍵面：從最上緣多高以內開始往下滑才算
    private static let topZoneHeight: CGFloat = 16

    func setUpDismissHandle() {
        let grabber = UIView()
        grabber.backgroundColor = SamsungTheme.grabber
        grabber.layer.cornerRadius = 2.5
        grabber.isUserInteractionEnabled = false
        grabber.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grabber)
        NSLayoutConstraint.activate([
            // 貼齊最上緣：再上面那條灰帶是系統畫的，擴充畫不到
            grabber.topAnchor.constraint(equalTo: view.topAnchor),
            grabber.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dismissPan(_:)))
        pan.delegate = self
        // 點鍵時不等這個手勢判斷完才送出，打字不會變慢
        pan.delaysTouchesEnded = false
        view.addGestureRecognizer(pan)
    }

    @objc private func dismissPan(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .ended else { return }
        let t = pan.translation(in: view)
        if t.y > Self.dismissDistance, t.y > abs(t.x) {
            dismissKeyboard()
        }
    }

    /// 只接從頂端（候選列那排，或沒有候選列時的最上緣）開始、往下的滑動；其他滑動照常給候選列和鍵
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let startY = pan.location(in: view).y - pan.translation(in: view).y
        let zone = candidateBar.isHidden ? Self.topZoneHeight : candidateBar.frame.maxY
        let v = pan.velocity(in: view)
        return startY <= zone && v.y > abs(v.x)
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }
}
