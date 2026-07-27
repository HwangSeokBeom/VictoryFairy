import SwiftUI

/// Pencil `일러스트 키트` 프레임의 손그림 일러스트.
///
/// 이 그림들은 앱의 시각적 정체성이라 비슷한 SF Symbol로 바꾸지 않고 원본 벡터를
/// 그대로 옮겼다. 기본적으로 장식이므로 VoiceOver에서 숨기며, 의미를 전달해야 하는
/// 자리에서는 사용하는 쪽이 라벨을 붙인다.
enum VFIllustration: String, CaseIterable {
    case baseball
    case pennant
    case sparkle
    case tape
    case cloud
    case rainCloud
    case glove
    case ticket
    case stadiumLight

    /// 원본 프레임 크기. 높이를 지정하면 이 비율로 확대·축소한다.
    var naturalSize: CGSize {
        switch self {
        case .baseball: CGSize(width: 48, height: 48)
        case .pennant: CGSize(width: 56, height: 34)
        case .sparkle: CGSize(width: 26, height: 26)
        case .tape: CGSize(width: 64, height: 22)
        case .cloud: CGSize(width: 52, height: 34)
        case .rainCloud: CGSize(width: 52, height: 46)
        case .glove: CGSize(width: 44, height: 44)
        case .ticket: CGSize(width: 56, height: 36)
        case .stadiumLight: CGSize(width: 40, height: 48)
        }
    }
}

/// 일러스트를 원하는 높이로 그린다. 너비는 원본 비율을 따른다.
struct VFIllustrationView: View {
    let illustration: VFIllustration
    let height: CGFloat
    /// VoiceOver 라벨. 비우면 장식으로 간주해 숨긴다.
    var accessibilityLabel: String?

    init(_ illustration: VFIllustration, height: CGFloat, accessibilityLabel: String? = nil) {
        self.illustration = illustration
        self.height = height
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        let natural = illustration.naturalSize
        let scale = height / natural.height
        artwork
            .frame(width: natural.width, height: natural.height, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: natural.width * scale, height: height, alignment: .topLeading)
            .modifier(VFIllustrationAccessibility(label: accessibilityLabel))
    }

    @ViewBuilder
    private var artwork: some View {
        switch illustration {
        case .baseball: baseball
        case .pennant: pennant
        case .sparkle: sparkle
        case .tape: tape
        case .cloud: cloud
        case .rainCloud: rainCloud
        case .glove: glove
        case .ticket: ticket
        case .stadiumLight: stadiumLight
        }
    }

    // MARK: - 개별 일러스트

    private var baseball: some View {
        ZStack(alignment: .topLeading) {
            Ellipse()
                .fill(VFColor.elevatedSurface)
                .overlay(Ellipse().stroke(VFColor.inkOutline, lineWidth: 1.6))
                .frame(width: 40, height: 40)
                .offset(x: 4, y: 4)
            stroked("M7.5 0.5c-5.7 8.1-6.1 22.3-0.3 30.9", (0, 0, 9, 32),
                    color: VFColor.primaryAction, width: 1.5)
                .frame(width: 9, height: 32).offset(x: 8, y: 8)
            stroked("M1.4 0.6c6 8.2 6.2 22.4 0.4 30.8", (0, 0, 9, 32),
                    color: VFColor.primaryAction, width: 1.5)
                .frame(width: 9, height: 32).offset(x: 31, y: 8)
            stroked("M0.6 2.4l4.8 1.2m-5.4 5.4l5 0.4m-5 7l5.2-0.2m-4.4 7l4.8-1", (0, 0, 10, 26),
                    color: VFColor.inkOutline, width: 1.2)
                .frame(width: 10, height: 26).offset(x: 6, y: 11)
            stroked("M9.2 2.6l-4.8 1.2m5.4 5.4l-5 0.2m4.8 7l-5-0.2m4.4 6.8l-4.6-0.8", (0, 0, 10, 26),
                    color: VFColor.inkOutline, width: 1.2)
                .frame(width: 10, height: 26).offset(x: 32, y: 11)
        }
    }

    private var pennant: some View {
        ZStack(alignment: .topLeading) {
            filled("M1 1.6c14-2 31-0.2 45.6 9.6-14.6 10.2-31.6 12.4-45.2 11.4-1.2-6.6-1-14.6-0.4-21z",
                   (0, 0, 48, 24), fill: VFColor.primaryAction,
                   stroke: VFColor.inkOutline, width: 1.5)
                .frame(width: 48, height: 24).offset(x: 6, y: 4)
            stroked("M1.2 0.5c0.4 9.5 0.6 19.5 0.2 29", (0, 0, 3, 30),
                    color: VFColor.inkOutline, width: 1.8)
                .frame(width: 3, height: 30).offset(x: 4, y: 2)
            stroked("M0.6 4.2c4.4-1.6 9.4-1.4 14.6-0.2", (0, 0, 16, 8),
                    color: VFColor.elevatedSurface, width: 1.8)
                .frame(width: 16, height: 8).offset(x: 14, y: 12)
        }
    }

    private var sparkle: some View {
        filled("M12 0.8c1 6.2 2.4 8.4 10.8 10.8-8.2 2.6-9.6 4.8-10.6 11.8-1.4-6.8-2.8-9.2-10.8-11.6 7.8-2.4 9.4-4.8 10.6-11z",
               (0, 0, 24, 24), fill: VFColor.attentionAccent,
               stroke: VFColor.inkOutline, width: 1.3)
            .frame(width: 24, height: 24).offset(x: 1, y: 1)
    }

    private var tape: some View {
        VFVectorPath("M2.4 2.6l3.6 1.6-4 2.6 3.6 2.2-3.4 2.6 3.8 2.2-3.4 3.6 56.8 1.2-3.2-3 3.8-2.4-3.6-2.6 3.4-2.4-3.8-2.4 3.6-4.2z",
                     viewBox: (0, 0, 62, 20))
            .fill(VFColor.attentionAccent)
            .opacity(0.75)
            .frame(width: 62, height: 20)
            .offset(x: 1, y: 1)
    }

    private var cloud: some View {
        filled("M10 25.4c-6.6 0-8.4-6.8-4-10.2-0.4-6.2 6-9 10.4-6.4 2-5.8 11.6-6.2 14.6-1.2 6.6-2.4 13 2.4 11.6 8.4 5 1.6 4.4 9-1.8 9.8-9.8 1.2-22.8 0.8-30.8-0.4z",
               (0, 0, 48, 27), fill: VFColor.infoAccentPale,
               stroke: VFColor.inkOutline, width: 1.5)
            .frame(width: 48, height: 27).offset(x: 2, y: 3)
    }

    private var rainCloud: some View {
        ZStack(alignment: .topLeading) {
            cloud
            stroked("M2.4 0.6l-1.8 5.8m11.4-5.4l-2 6.8m11.6-7.4l-1.8 5.8m7.6-2.6l-1.4 5",
                    (0, 0, 28, 12), color: VFColor.infoAccent, width: 1.8)
                .frame(width: 28, height: 12).offset(x: 12, y: 32)
        }
    }

    private var glove: some View {
        ZStack(alignment: .topLeading) {
            filled("M6.6 21c-3.6-4-5.6-11.4-2.6-15.6 3.4-4.6 11-5 16.6-3.2 6.4 2 12.8 6.8 14 14.2 1.2 7.6-1.6 16-8.2 20.2-6 2.8-13.8 1.8-17.4-3-2.4-3.4-2.6-8.6-2.4-12.6z",
                   (0, 0, 36, 39), fill: VFColor.primaryActionPale,
                   stroke: VFColor.inkOutline, width: 1.5)
                .frame(width: 36, height: 39).offset(x: 4, y: 3)
            stroked("M2 12.6c4.4-4.2 11-7 18.4-7.6m-15.8 12.6c4.4-4.2 10.8-7 18-7.8m-14.6 12.6c4-3.8 9.6-6.4 16-7.4",
                    (0, 0, 26, 26), color: VFColor.primaryAction, width: 1.4)
                .frame(width: 26, height: 26).offset(x: 10, y: 8)
        }
    }

    private var ticket: some View {
        ZStack(alignment: .topLeading) {
            filled("M2 1.6c10-1 22-0.6 32.6-0.4a3.4 3.4 0 0 0 6.4 0.2c4 0 7.2 0.4 8.6 1.2 1 8 1.2 19.2 0.4 27.4-4.4 0.8-6 0.6-9 0.4a3.4 3.4 0 0 0-6.2 0.2c-11.8 1-24.8 0.4-32.4-0.2-1.4-8.8-1.2-20-0.4-28.8z",
                   (0, 0, 52, 32), fill: VFColor.highlightSurface,
                   stroke: VFColor.inkOutline, width: 1.5)
                .frame(width: 52, height: 32).offset(x: 2, y: 2)
            stroked("M1 0.4l0.2 2.4m-0.4 3.2l0.2 2.4m0.2 3l-0.2 2.4m0 3.2l0.2 2.4",
                    (0, 0, 2, 20), color: VFColor.bodySecondary, width: 1.2)
                .frame(width: 2, height: 20).offset(x: 39, y: 8)
            stroked("M0.6 2.2c6.4-0.8 13.4-0.6 20.4-0.2m-20.6 5.4c5.6-0.6 9.6-0.4 14.2-0.2m-13.8 5.2c4.2-0.4 7.2-0.2 10.2 0",
                    (0, 0, 24, 14), color: VFColor.primaryAction, width: 1.5)
                .frame(width: 24, height: 14).offset(x: 8, y: 11)
        }
    }

    private var stadiumLight: some View {
        ZStack(alignment: .topLeading) {
            filled("M3 1.6c7-1 15-1 22.2 0.2 1.4 3.6 1.6 7.2 0.8 10.6-8 1.2-16 1-23.8-0.2-0.6-3.6-0.2-7.4 0.8-10.6z",
                   (0, 0, 28, 14), fill: VFColor.highlightSurface,
                   stroke: VFColor.inkOutline, width: 1.5)
                .frame(width: 28, height: 14).offset(x: 6, y: 4)
            stroked("M2.4 2l0.2 3.6m4.8-4l0.2 4.2m4.8-3.8l0.2 3.6m4.8-3.8l0.2 4",
                    (0, 0, 20, 8), color: VFColor.primaryAction, width: 2)
                .frame(width: 20, height: 8).offset(x: 10, y: 7)
            stroked("M4 0.5l-0.4 27m-3-0.1l6.8-0.2", (0, 0, 8, 28),
                    color: VFColor.inkOutline, width: 1.7)
                .frame(width: 8, height: 28).offset(x: 16, y: 18)
        }
    }

    // MARK: - 그리기 도우미

    private func stroked(
        _ geometry: String,
        _ viewBox: (CGFloat, CGFloat, CGFloat, CGFloat),
        color: Color,
        width: CGFloat
    ) -> some View {
        VFVectorPath(geometry, viewBox: viewBox)
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func filled(
        _ geometry: String,
        _ viewBox: (CGFloat, CGFloat, CGFloat, CGFloat),
        fill: Color,
        stroke: Color,
        width: CGFloat
    ) -> some View {
        let shape = VFVectorPath(geometry, viewBox: viewBox)
        return shape
            .fill(fill)
            .overlay(shape.stroke(stroke, style: StrokeStyle(lineWidth: width, lineJoin: .round)))
    }
}

/// 라벨이 없으면 장식으로 보고 숨긴다.
private struct VFIllustrationAccessibility: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityElement().accessibilityLabel(label)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

#Preview("일러스트 키트") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(VFIllustration.allCases, id: \.self) { illustration in
                VStack(spacing: VFSpacing.xs) {
                    VFIllustrationView(illustration, height: 48)
                        .frame(height: 52)
                    Text(illustration.rawValue)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.lg)
    }
    .vfScreenBackground()
}
