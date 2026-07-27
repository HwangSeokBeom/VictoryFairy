import SwiftUI

/// Pencil 일러스트의 SVG path 데이터를 그대로 그리는 Shape.
///
/// 일러스트 키트는 손으로 그린 곡선이라 SF Symbol로 대체할 수 없다. 원본 좌표를
/// 유지한 채 `viewBox`를 실제 그려질 사각형에 매핑해, 어떤 크기에서도 같은 모양이
/// 나오게 한다.
struct VFVectorPath: Shape {
    /// SVG `d` 속성 문자열.
    let geometry: String
    /// 원본 좌표계 [x, y, width, height].
    let viewBox: CGRect

    init(_ geometry: String, viewBox: CGRect) {
        self.geometry = geometry
        self.viewBox = viewBox
    }

    init(_ geometry: String, viewBox: (CGFloat, CGFloat, CGFloat, CGFloat)) {
        self.init(geometry, viewBox: CGRect(x: viewBox.0, y: viewBox.1, width: viewBox.2, height: viewBox.3))
    }

    func path(in rect: CGRect) -> Path {
        let parsed = VFSVGPathParser.parse(geometry)
        guard viewBox.width > 0, viewBox.height > 0 else { return parsed }
        let scaleX = rect.width / viewBox.width
        let scaleY = rect.height / viewBox.height
        let transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -viewBox.minX, y: -viewBox.minY)
        return parsed.applying(transform)
    }
}

/// SVG path 문자열을 `Path`로 옮기는 최소 파서.
///
/// Pencil 일러스트가 실제로 쓰는 명령만 다룬다: M/m, L/l, H/h, V/v, C/c, S/s,
/// Q/q, T/t, A/a, Z/z. 좌표가 반복되면 직전 명령이 이어지는 SVG 규칙도 따른다.
enum VFSVGPathParser {
    static func parse(_ definition: String) -> Path {
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?
        var lastQuadControl: CGPoint?
        var previousCommand: Character?

        var scanner = Tokenizer(definition)

        while let command = scanner.nextCommand() {
            let isRelative = command.isLowercase
            let upper = Character(command.uppercased())

            // 좌표만 반복되는 경우 직전 명령을 이어간다. M 뒤의 반복은 L로 취급한다.
            var effective = upper
            if upper == Character("\u{0}") {
                guard let previous = previousCommand else { break }
                effective = previous == "M" ? "L" : previous
            }

            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }

            switch effective {
            case "M":
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                current = point(x, y)
                subpathStart = current
                path.move(to: current)
                lastControl = nil
                lastQuadControl = nil
            case "L":
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                current = point(x, y)
                path.addLine(to: current)
                lastControl = nil
                lastQuadControl = nil
            case "H":
                guard let x = scanner.nextNumber() else { return path }
                current = CGPoint(x: isRelative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
                lastQuadControl = nil
            case "V":
                guard let y = scanner.nextNumber() else { return path }
                current = CGPoint(x: current.x, y: isRelative ? current.y + y : y)
                path.addLine(to: current)
                lastControl = nil
                lastQuadControl = nil
            case "C":
                guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                      let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                let control1 = point(x1, y1)
                let control2 = point(x2, y2)
                current = point(x, y)
                path.addCurve(to: current, control1: control1, control2: control2)
                lastControl = control2
                lastQuadControl = nil
            case "S":
                guard let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                let control1 = reflect(lastControl, around: current)
                let control2 = point(x2, y2)
                current = point(x, y)
                path.addCurve(to: current, control1: control1, control2: control2)
                lastControl = control2
                lastQuadControl = nil
            case "Q":
                guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                let control = point(x1, y1)
                current = point(x, y)
                path.addQuadCurve(to: current, control: control)
                lastQuadControl = control
                lastControl = nil
            case "T":
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                let control = reflect(lastQuadControl, around: current)
                current = point(x, y)
                path.addQuadCurve(to: current, control: control)
                lastQuadControl = control
                lastControl = nil
            case "A":
                guard let rx = scanner.nextNumber(), let ry = scanner.nextNumber(),
                      let rotation = scanner.nextNumber(), let largeArc = scanner.nextNumber(),
                      let sweep = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                let end = point(x, y)
                appendArc(
                    to: &path, from: current, to: end,
                    rx: rx, ry: ry, rotationDegrees: rotation,
                    largeArc: largeArc != 0, sweep: sweep != 0
                )
                current = end
                lastControl = nil
                lastQuadControl = nil
            case "Z":
                path.closeSubpath()
                current = subpathStart
                lastControl = nil
                lastQuadControl = nil
            default:
                return path
            }

            previousCommand = effective
        }

        return path
    }

    private static func reflect(_ control: CGPoint?, around point: CGPoint) -> CGPoint {
        guard let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    /// SVG 엔드포인트 방식 호(arc)를 중심점 방식으로 바꿔 베지어로 근사한다.
    /// W3C SVG 명세 F.6.5의 변환 절차를 그대로 따른다.
    private static func appendArc(
        to path: inout Path,
        from start: CGPoint,
        to end: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        rotationDegrees: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) {
        guard rx != 0, ry != 0 else {
            path.addLine(to: end)
            return
        }
        var radiusX = abs(rx)
        var radiusY = abs(ry)
        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        let dx2 = (start.x - end.x) / 2
        let dy2 = (start.y - end.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        // 반지름이 두 점을 잇기에 모자라면 명세대로 키운다.
        let lambda = (x1p * x1p) / (radiusX * radiusX) + (y1p * y1p) / (radiusY * radiusY)
        if lambda > 1 {
            let scale = sqrt(lambda)
            radiusX *= scale
            radiusY *= scale
        }

        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let numerator = max(
            0,
            radiusX * radiusX * radiusY * radiusY
                - radiusX * radiusX * y1p * y1p
                - radiusY * radiusY * x1p * x1p
        )
        let denominator = radiusX * radiusX * y1p * y1p + radiusY * radiusY * x1p * x1p
        let coefficient = denominator == 0 ? 0 : sign * sqrt(numerator / denominator)
        let cxp = coefficient * radiusX * y1p / radiusY
        let cyp = -coefficient * radiusY * x1p / radiusX

        let cx = cosPhi * cxp - sinPhi * cyp + (start.x + end.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (start.y + end.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            guard len != 0 else { return 0 }
            let clamped = min(1, max(-1, dot / len))
            let value = acos(clamped)
            return (ux * vy - uy * vx) < 0 ? -value : value
        }

        let startAngle = angle(1, 0, (x1p - cxp) / radiusX, (y1p - cyp) / radiusY)
        var deltaAngle = angle(
            (x1p - cxp) / radiusX, (y1p - cyp) / radiusY,
            (-x1p - cxp) / radiusX, (-y1p - cyp) / radiusY
        )
        if !sweep, deltaAngle > 0 { deltaAngle -= 2 * .pi }
        if sweep, deltaAngle < 0 { deltaAngle += 2 * .pi }

        // 90도 이하 구간으로 나눠 각 구간을 3차 베지어로 근사한다.
        let segments = max(1, Int(ceil(abs(deltaAngle) / (.pi / 2))))
        let segmentAngle = deltaAngle / CGFloat(segments)
        let alpha = 4.0 / 3.0 * tan(segmentAngle / 4)

        var theta = startAngle
        for _ in 0..<segments {
            let nextTheta = theta + segmentAngle
            let cosTheta = cos(theta), sinTheta = sin(theta)
            let cosNext = cos(nextTheta), sinNext = sin(nextTheta)

            func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(
                    x: cosPhi * radiusX * x - sinPhi * radiusY * y + cx,
                    y: sinPhi * radiusX * x + cosPhi * radiusY * y + cy
                )
            }

            let endPoint = map(cosNext, sinNext)
            let control1 = map(cosTheta - alpha * sinTheta, sinTheta + alpha * cosTheta)
            let control2 = map(cosNext + alpha * sinNext, sinNext - alpha * cosNext)
            path.addCurve(to: endPoint, control1: control1, control2: control2)
            theta = nextTheta
        }
    }

    /// path 문자열을 명령과 숫자로 끊어 읽는다.
    private struct Tokenizer {
        private let characters: [Character]
        private var index: Int = 0

        init(_ string: String) {
            characters = Array(string)
        }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index] == " " || characters[index] == "," || characters[index] == "\n" || characters[index] == "\t" {
                index += 1
            }
        }

        /// 다음 명령 문자를 읽는다. 숫자가 이어지면 NUL을 돌려주어 "직전 명령 반복"을 알린다.
        mutating func nextCommand() -> Character? {
            skipSeparators()
            guard index < characters.count else { return nil }
            let character = characters[index]
            if character.isLetter {
                index += 1
                return character
            }
            return Character("\u{0}")
        }

        mutating func nextNumber() -> CGFloat? {
            skipSeparators()
            guard index < characters.count else { return nil }
            var literal = ""
            if characters[index] == "-" || characters[index] == "+" {
                literal.append(characters[index])
                index += 1
            }
            var hasSeenExponent = false
            while index < characters.count {
                let character = characters[index]
                if character.isNumber || character == "." {
                    literal.append(character)
                    index += 1
                } else if character == "e" || character == "E" {
                    hasSeenExponent = true
                    literal.append(character)
                    index += 1
                } else if hasSeenExponent, character == "-" || character == "+", let last = literal.last, last == "e" || last == "E" {
                    literal.append(character)
                    index += 1
                } else {
                    break
                }
            }
            guard let value = Double(literal) else { return nil }
            return CGFloat(value)
        }
    }
}
