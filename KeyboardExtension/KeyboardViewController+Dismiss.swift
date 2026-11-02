import UIKit

/// 收鍵盤：從任何一顆鍵或候選字往下拖（或往下撥）就收起（有些 app 沒地方收鍵盤，鍵盤又大，關不掉很麻煩）。
/// 往下拖由每顆鍵自己判斷（見 KeyButton）；最上面中間的拖曳條只是提示有這個動作
extension KeyboardViewController {
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
        keyboardView.onSwipeDown = { [weak self] in self?.dismissKeyboard() }
        candidateBar.onSwipeDown = { [weak self] in self?.dismissKeyboard() }
    }
}
