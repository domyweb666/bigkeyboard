import UIKit

/// 收鍵盤：在鍵盤任何地方往下拖就收起（有些 app 沒地方收鍵盤，鍵盤又大，關不掉很麻煩）。
/// 最上面中間的拖曳條只是提示有這個手勢
extension KeyboardViewController: UIGestureRecognizerDelegate {
    /// 往下拖超過這個距離就收（約一排鍵高）。點鍵時手指滑一點點不會到這麼遠
    private static let dismissDistance: CGFloat = 60

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
        // 不搶鍵和候選的觸控：手勢判斷中，按鍵照常按下、放開照常送出，打字不會變慢或被吃掉
        pan.cancelsTouchesInView = false
        pan.delaysTouchesEnded = false
        view.addGestureRecognizer(pan)
    }

    /// 手指還沒放開、拖夠遠就收，不用等放開
    @objc private func dismissPan(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .changed || pan.state == .ended else { return }
        let t = pan.translation(in: view)
        guard t.y > Self.dismissDistance, t.y > abs(t.x) else { return }
        // 先結束手勢，免得同一次拖曳收兩次
        pan.isEnabled = false
        pan.isEnabled = true
        dismissKeyboard()
    }

    /// 只接往下為主的拖曳；左右滑照常給候選列。展開全部候選時往下滑是在捲清單，不收
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let v = pan.velocity(in: view)
        return !expanded && v.y > abs(v.x)
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }
}
