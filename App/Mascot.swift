import SwiftUI

/// 豆鍵的吉祥物：紅鍵帽頭的火柴人。身體是八個關節角度，每個動作是角度隨時間變化的一組數值
/// （從「茄子火柴人動作庫」搬過來，頭套換成 App icon 的紅鍵帽和豆子）。只在 App 裡用，鍵盤擴充不放
struct MascotView: View {
    enum Action {
        case idle
        case wave
        case pointDown
        case cheer
    }

    let action: Action
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    /// 換動作時從上一個動作的姿勢過渡過去
    @State private var previous: Action?
    @State private var switchedAt = Date.now

    /// 換動作的過渡時間（秒）
    private static let blendDuration = 0.28

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                MascotDrawing(pose: pose(at: timeline.date), ink: ink).draw(in: &context, size: size)
            }
        }
        .aspectRatio(MascotRig.viewBox.width / MascotRig.viewBox.height, contentMode: .fit)
        .onChange(of: action) { old, _ in
            previous = old
            switchedAt = .now
        }
        .accessibilityHidden(true)
    }

    /// 減少動態效果開著時停在動作一開始的姿勢，不過渡
    private func pose(at date: Date) -> MascotPose {
        let time = reduceMotion ? 0 : date.timeIntervalSince(switchedAt)
        let target = MascotMoves.pose(action, at: time)
        guard !reduceMotion, let previous, time < Self.blendDuration else { return target }
        let k = time / Self.blendDuration
        return MascotPose.blend(MascotMoves.pose(previous, at: time), target, k * k * (3 - 2 * k))
    }

    private var ink: Color {
        colorScheme == .dark ? MascotArt.limbDark : MascotArt.limbLight
    }
}

/// 吉祥物的角色色：鍵帽、豆子取自 App icon（docs/icon/douJian.svg），臉是白底深色五官。
/// 這是角色本身的顏色，不是介面色，所以不走 Domy 代號；只有四肢跟著深淺色換，免得在黑底上看不見
private enum MascotArt {
    static let keycapTop = Color(uiColor: UIColor(domyHex: 0xEE5058))
    static let keycapSide = Color(uiColor: UIColor(domyHex: 0xA82231))
    static let bean = Color(uiColor: UIColor(domyHex: 0xF8EAD2))
    static let face = Color.white
    static let feature = Color(uiColor: UIColor(domyHex: 0x2B2329))
    static let limbLight = Color(uiColor: UIColor(domyHex: 0x39323A))
    static let limbDark = Color(uiColor: UIColor(domyHex: 0xE9E4EC))
}

/// 骨架尺寸（畫布座標，0° 是垂直向下，正值往右轉）
private enum MascotRig {
    static let viewBox = CGRect(x: 0, y: -50, width: 320, height: 450)
    static let hipX: CGFloat = 160
    static let hipY: CGFloat = 260
    static let ground: CGFloat = 380
    static let thigh: CGFloat = 62
    static let shin: CGFloat = 62
    static let torso: CGFloat = 78
    static let shoulderDrop: CGFloat = 12
    static let shoulderHalf: CGFloat = 6
    static let upper: CGFloat = 44
    static let fore: CGFloat = 44
}

/// 一個瞬間的姿勢。肩、髖是相對垂直向下的角度，肘、膝是相對上一節的角度
struct MascotPose {
    var lean = 0.0
    var head = 0.0
    var hy = 0.0
    var sh = 0.0
    var ry = 0.0
    var squash = 0.0
    var lS = -38.0
    var lE = 143.0
    var rS = 38.0
    var rE = -143.0
    var lH = -14.0
    var lK = 0.0
    var rH = 14.0
    var rK = 0.0
    var eyeH = 12.0
    var lookX = 0.0
    var lookY = 0.0
    var brow = 2.0
    var browY = 0.0
    /// 大於 0.5：笑瞇眼
    var happy = 0.0
    /// 大於 0.5：張嘴笑
    var mouthOpen = 0.0

    private static let keys: [WritableKeyPath<MascotPose, Double>] = [
        \.lean, \.head, \.hy, \.sh, \.ry, \.squash, \.lS, \.lE, \.rS, \.rE, \.lH, \.lK, \.rH, \.rK,
        \.eyeH, \.lookX, \.lookY, \.brow, \.browY, \.happy, \.mouthOpen,
    ]

    static func blend(_ from: MascotPose, _ to: MascotPose, _ k: Double) -> MascotPose {
        var result = to
        for key in keys {
            result[keyPath: key] = from[keyPath: key] + (to[keyPath: key] - from[keyPath: key]) * k
        }
        return result
    }
}

/// 各動作的數值（照動作庫原樣搬）
private enum MascotMoves {
    static func pose(_ action: MascotView.Action, at t: Double) -> MascotPose {
        switch action {
        case .idle: idle(t)
        case .wave: wave(t)
        case .pointDown: pointDown(t)
        case .cheer: cheer(t)
        }
    }

    private static func idle(_ t: Double) -> MascotPose {
        var p = MascotPose()
        let breath = sin(t * 2.2)
        p.sh = -1.2 * breath
        p.hy = -1.2 * breath
        p.lean = 1.4 * sin(t * 1.1)
        p.head = 1.5 * sin(t * 0.9)
        p.eyeH = t.truncatingRemainder(dividingBy: 3.6) > 3.46 ? 1.5 : 12
        return p
    }

    private static func wave(_ t: Double) -> MascotPose {
        var p = MascotPose()
        p.rS = 110
        p.rE = 40 + 22 * sin(t * 9)
        p.lS = -16
        p.lE = -6
        p.head = 5 + 2 * sin(t * 4.5)
        p.lean = 2
        p.brow = 5
        p.browY = -1
        p.hy = -sin(t * 4.5)
        return p
    }

    private static func pointDown(_ t: Double) -> MascotPose {
        var p = MascotPose()
        let bob = sin(t * 5)
        p.rS = 30
        p.rE = 8
        p.lS = -40
        p.lE = 100
        p.lean = 2
        p.head = 9 + 1.5 * bob
        p.lookX = 2
        p.lookY = 3.5
        p.brow = 4
        return p
    }

    private static func cheer(_ t: Double) -> MascotPose {
        let period = 0.72
        let phase = t.truncatingRemainder(dividingBy: period) / period
        let hop = phase < 0.8 ? sin(Double.pi * phase / 0.8) : 0
        let land = phase >= 0.8 ? sin(Double.pi * (phase - 0.8) / 0.2) : 0
        let shake = sin(t * 15)
        var p = MascotPose()
        p.ry = -34 * hop
        p.squash = 0.07 * land
        p.lS = -105
        p.lE = -62 - 8 * shake
        p.rS = 105
        p.rE = 62 + 8 * shake
        p.lH = -14 - 12 * hop
        p.lK = 34 * hop
        p.rH = 14 + 12 * hop
        p.rK = -34 * hop
        p.brow = -4
        p.browY = -3
        p.happy = 1
        p.mouthOpen = 1
        p.head = 0.9 * shake
        return p
    }
}

/// 把一個姿勢畫進 Canvas：影子 → 腿 → 身體 → 頭 → 手（手蓋在頭上）
private struct MascotDrawing {
    let pose: MascotPose
    let ink: Color

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let box = MascotRig.viewBox
        let scale = min(size.width / box.width, size.height / box.height)
        context.translateBy(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        drawShadow(in: context)

        // 落地時以腳底為中心壓扁一點
        var body = context
        body.translateBy(x: MascotRig.hipX, y: MascotRig.ground)
        body.scaleBy(x: 1 + pose.squash * 0.6, y: 1 - pose.squash)
        body.translateBy(x: -MascotRig.hipX, y: -MascotRig.ground)

        let hip = CGPoint(x: MascotRig.hipX, y: MascotRig.hipY + pose.ry)
        let up = direction(180 - pose.lean)
        let neck = move(hip, up, MascotRig.torso)
        var shoulder = move(hip, up, MascotRig.torso - MascotRig.shoulderDrop)
        shoulder.y += pose.sh

        drawLeg(in: body, hip: hip, hipAngle: pose.lH, knee: pose.lK, side: -1)
        drawLeg(in: body, hip: hip, hipAngle: pose.rH, knee: pose.rK, side: 1)
        segment(in: body, hip, CGPoint(x: neck.x, y: neck.y + pose.sh * 0.5), width: 9)

        var head = body
        head.translateBy(x: neck.x, y: neck.y + pose.hy + pose.sh * 0.5)
        head.rotate(by: .degrees(pose.head + pose.lean))
        MascotHead(pose: pose).draw(in: head)

        drawArm(in: body, shoulder: shoulder, angle: pose.lS, elbow: pose.lE, side: -1)
        drawArm(in: body, shoulder: shoulder, angle: pose.rS, elbow: pose.rE, side: 1)
    }

    /// 跳起來時影子變小變淡
    private func drawShadow(in context: GraphicsContext) {
        let lift = max(0, -pose.ry / 40)
        let rx = 62 * (1 - lift * 0.35)
        let ry = 8 * (1 - lift * 0.35)
        let rect = CGRect(x: MascotRig.hipX - rx, y: MascotRig.ground + 7 - ry, width: rx * 2, height: ry * 2)
        context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.16 * (1 - lift * 0.5))))
    }

    private func drawLeg(in context: GraphicsContext, hip: CGPoint, hipAngle: Double, knee: Double, side: CGFloat) {
        let kneePoint = move(hip, direction(hipAngle), MascotRig.thigh)
        let ankle = move(kneePoint, direction(hipAngle + knee), MascotRig.shin)
        segment(in: context, hip, kneePoint, width: 9)
        segment(in: context, kneePoint, ankle, width: 9)
        segment(in: context, ankle, CGPoint(x: ankle.x + side * 12, y: ankle.y + 1), width: 9)
    }

    private func drawArm(in context: GraphicsContext, shoulder: CGPoint, angle: Double, elbow: Double, side: CGFloat) {
        let start = CGPoint(x: shoulder.x + side * MascotRig.shoulderHalf, y: shoulder.y)
        let elbowPoint = move(start, direction(angle), MascotRig.upper)
        let hand = move(elbowPoint, direction(angle + elbow), MascotRig.fore)
        segment(in: context, start, elbowPoint, width: 8.5)
        segment(in: context, elbowPoint, hand, width: 8.5)
    }

    private func segment(in context: GraphicsContext, _ from: CGPoint, _ to: CGPoint, width: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    /// 角度轉方向：0° 朝下、正值往右
    private func direction(_ degrees: Double) -> CGVector {
        let radians = degrees * .pi / 180
        return CGVector(dx: sin(radians), dy: cos(radians))
    }

    private func move(_ point: CGPoint, _ vector: CGVector, _ length: CGFloat) -> CGPoint {
        CGPoint(x: point.x + vector.dx * length, y: point.y + vector.dy * length)
    }
}

/// 頭：紅鍵帽（深紅側邊＋紅色鍵面）、頂上一顆豆子、白臉。座標以脖子為原點
private struct MascotHead {
    let pose: MascotPose

    /// App icon 那顆豆子的輪廓（起點 -240,-20）：每段曲線是終點、控制點 1、控制點 2 的 x,y
    private static let beanCurves: [[CGFloat]] = [
        [0, -120, -240, -150, -90, -170],
        [240, -10, 90, -170, 240, -150],
        [60, 110, 240, 120, 120, 160],
        [-60, 110, 30, 85, -30, 85],
        [-240, -20, -120, 160, -240, 110],
    ]

    func draw(in context: GraphicsContext) {
        let side = CGRect(x: -50, y: -88, width: 100, height: 96)
        let top = side.offsetBy(dx: 0, dy: -10)
        context.fill(Path(roundedRect: side, cornerRadius: 26), with: .color(MascotArt.keycapSide))
        context.fill(Path(roundedRect: top, cornerRadius: 26), with: .color(MascotArt.keycapTop))
        drawBean(in: context)
        let face = CGRect(x: -30, y: -76, width: 60, height: 60)
        context.fill(Path(ellipseIn: face), with: .color(MascotArt.face))
        drawEye(in: context, side: -1)
        drawEye(in: context, side: 1)
        drawMouth(in: context)
    }

    /// 豆子：App icon 那顆豆子縮小、斜放在鍵帽頂上
    private func drawBean(in context: GraphicsContext) {
        var bean = context
        bean.translateBy(x: 10, y: -100)
        bean.rotate(by: .degrees(-14))
        bean.scaleBy(x: 0.13, y: 0.13)
        var path = Path()
        path.move(to: CGPoint(x: -240, y: -20))
        for c in Self.beanCurves {
            path.addCurve(
                to: CGPoint(x: c[0], y: c[1]),
                control1: CGPoint(x: c[2], y: c[3]),
                control2: CGPoint(x: c[4], y: c[5])
            )
        }
        path.closeSubpath()
        bean.fill(path, with: .color(MascotArt.bean))
        let stripe = CGRect(x: -95, y: -70, width: 190, height: 56)
        bean.fill(Path(roundedRect: stripe, cornerRadius: 28), with: .color(MascotArt.keycapSide))
    }

    private func drawEye(in context: GraphicsContext, side: CGFloat) {
        let cx = side * 11 + pose.lookX
        let cy = -48 + pose.lookY
        if pose.happy > 0.5 {
            var arc = Path()
            arc.move(to: CGPoint(x: cx - 5, y: cy + 3))
            arc.addQuadCurve(to: CGPoint(x: cx + 5, y: cy + 3), control: CGPoint(x: cx, y: cy - 6))
            stroke(arc, in: context, width: 3.6)
        } else {
            let height = max(1.5, pose.eyeH)
            let eye = CGRect(x: cx - 2.3, y: cy - height / 2, width: 4.6, height: height)
            context.fill(Path(roundedRect: eye, cornerRadius: 2.3), with: .color(MascotArt.feature))
        }
        let bx = side * 12 + pose.lookX * 0.5
        let by = -61 + pose.browY + pose.lookY * 0.5
        let radians = pose.brow * .pi / 180
        let dx = 8 * cos(radians)
        let dy = 8 * sin(radians)
        var brow = Path()
        brow.move(to: CGPoint(x: bx - side * dx, y: by + dy))
        brow.addLine(to: CGPoint(x: bx + side * dx, y: by - dy))
        stroke(brow, in: context, width: 3.4)
    }

    private func drawMouth(in context: GraphicsContext) {
        let mx = pose.lookX * 0.5
        let my = -30 + pose.lookY * 0.5
        var mouth = Path()
        if pose.mouthOpen > 0.5 {
            mouth.move(to: CGPoint(x: mx - 7, y: my - 2))
            mouth.addQuadCurve(to: CGPoint(x: mx + 7, y: my - 2), control: CGPoint(x: mx, y: my + 10))
            mouth.closeSubpath()
            context.fill(mouth, with: .color(MascotArt.feature))
        } else {
            mouth.move(to: CGPoint(x: mx - 6, y: my - 1))
            mouth.addQuadCurve(to: CGPoint(x: mx + 6, y: my - 1), control: CGPoint(x: mx, y: my + 5))
            stroke(mouth, in: context, width: 3)
        }
    }

    private func stroke(_ path: Path, in context: GraphicsContext, width: CGFloat) {
        context.stroke(path, with: .color(MascotArt.feature), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
