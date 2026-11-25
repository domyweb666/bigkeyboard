import UIKit

/// 這一下也可能是想按的注音鍵，和它的代價（越大越不可能）
struct KeyAlternative {
    let symbol: String
    let cost: Double
}

/// 鄰鍵容錯：照手指按下的位置，算旁邊哪幾顆注音鍵也有可能。引擎拿去找「換一個鍵就通順」的整句
extension KeyboardView {
    /// b 這次按下的鄰鍵，代價小的在前。落點記在每顆鍵自己身上，兩指快打不會混到
    func alternatives(for b: KeyButton) -> [KeyAlternative] {
        guard let pressed = specs[b], case .bopomofo = pressed.action else { return [] }
        let point = lifted(convert(b.trackStart, from: nil))
        let own = b.convert(b.bounds, to: self)
        // 手指落點的散布：照鍵距、排距的比例
        let sigma = CGSize(
            width: SamsungTheme.touchSigmaRatio * (own.width + SamsungTheme.keyGap),
            height: SamsungTheme.touchSigmaRatio * (own.height + SamsungTheme.rowGap)
        )
        let ownSpread = Self.spread(of: point, from: own, sigma: sigma)
        var out: [KeyAlternative] = []
        for other in buttons where other !== b {
            guard let spec = specs[other], case let .bopomofo(symbol) = spec.action else { continue }
            let spread = Self.spread(of: point, from: other.convert(other.bounds, to: self), sigma: sigma)
            let cost = SamsungTheme.alternativeBaseCost + max(0, Self.halfLogE * (spread - ownSpread))
            if cost <= SamsungTheme.alternativeMaxCost {
                out.append(KeyAlternative(symbol: symbol, cost: cost))
            }
        }
        return Array(out.sorted { $0.cost < $1.cost }.prefix(SamsungTheme.alternativeMaxCount))
    }

    /// 常態分布的指數換成以 10 為底（詞庫的分數是 log10）：log10(e) ÷ 2
    private static let halfLogE = 0.434 / 2

    /// 落點離鍵中心幾個標準差的平方
    private static func spread(of point: CGPoint, from frame: CGRect, sigma: CGSize) -> Double {
        let x = Double((point.x - frame.midX) / sigma.width)
        let y = Double((point.y - frame.midY) / sigma.height)
        return x * x + y * y
    }
}
