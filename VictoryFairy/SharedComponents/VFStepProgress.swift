import SwiftUI

/// Pencil `08_RecordCreate_Step1`의 `진행 표시`(`u9ULlc`).
///
/// 점 · 연결선 · 라벨 세 줄로 "지금 몇 번째 단계인가"를 알린다. 여러 단계를 가진
/// 어떤 흐름에서도 쓸 수 있도록 단계 이름 목록만 받는다 — 기록 작성 1단계 전용으로
/// 이름 짓지 않는다.
///
/// 노드 근거(m34WD):
/// - `jZ6G3` 진행 점: 12×12 원 3개, 사이를 잇는 2pt 선
/// - 현재 점 `S3wHWi` fill `#F2B63C`(primaryAction) + stroke `#232A3C`(inkOutline) 1.2
/// - 지난/앞선 점 `aOA34`·`Oz6va` fill `#EAEAE6`(subtleSurface) + stroke `#E2E3E1`(hairline)
/// - 연결선 `W1wq86` stroke `#E2E3E1` 2
/// - `XkuSg` 진행 라벨: 11pt, 현재 `#D99A26`(primaryActionDeep)/600, 나머지 `#8B909E`(bodyTertiary)
struct VFStepProgress: View {
    /// 각 단계의 표시 이름. 화면에 그대로 보이는 문구다.
    let titles: [String]
    /// 지금 단계의 0부터 시작하는 자리.
    let currentIndex: Int

    /// 점 지름. Pencil 12pt를 Dynamic Type에 맞춰 키운다.
    @ScaledMetric(relativeTo: .caption2) private var dotDiameter: CGFloat = 12
    @ScaledMetric(relativeTo: .caption2) private var connectorHeight: CGFloat = 2

    private var safeIndex: Int { min(max(currentIndex, 0), max(titles.count - 1, 0)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            dotRow
            labelRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 점·선·라벨은 따로 읽히면 뜻이 없다. 한 덩어리로 한 문장만 읽는다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityStatement)
        .accessibilityIdentifier("recordCreate.progress")
    }

    private var dotRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, _ in
                if index > 0 {
                    Rectangle()
                        .fill(VFColor.hairline)
                        .frame(height: connectorHeight)
                        .frame(maxWidth: .infinity)
                }
                Circle()
                    .fill(index == safeIndex ? VFColor.primaryAction : VFColor.subtleSurface)
                    .overlay(
                        Circle().stroke(
                            index == safeIndex ? VFColor.inkOutline : VFColor.hairline,
                            lineWidth: 1.2
                        )
                    )
                    .frame(width: dotDiameter, height: dotDiameter)
            }
        }
    }

    private var labelRow: some View {
        HStack(alignment: .top, spacing: VFSpacing.xxs) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(title)
                    .font(VFTypography.badge)
                    .fontWeight(index == safeIndex ? .semibold : .regular)
                    .foregroundStyle(index == safeIndex ? VFColor.primaryActionDeep : VFColor.bodyTertiary)
                    // 큰 글자에서 세 라벨이 겹치지 않도록 줄바꿈을 허용한다.
                    // 줄이지 않는다 — 축소는 레이아웃 실패를 가린다.
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity,
                        alignment: index == 0 ? .leading : (index == titles.count - 1 ? .trailing : .center)
                    )
                    .multilineTextAlignment(index == 0 ? .leading : (index == titles.count - 1 ? .trailing : .center))
            }
        }
    }

    /// VoiceOver가 읽을 한 문장. "3단계 중 1단계, 경기".
    private var accessibilityStatement: String {
        guard !titles.isEmpty else { return "" }
        return "\(titles.count)단계 중 \(safeIndex + 1)단계, \(titles[safeIndex])"
    }
}

#Preview("진행 표시 · 1단계") {
    VStack(spacing: VFSpacing.xl) {
        VFStepProgress(titles: RecordCreateStep.allCases.map(\.accessibilityTitle), currentIndex: 0)
        VFStepProgress(titles: RecordCreateStep.allCases.map(\.accessibilityTitle), currentIndex: 1)
        VFStepProgress(titles: RecordCreateStep.allCases.map(\.accessibilityTitle), currentIndex: 2)
    }
    .padding(VFSpacing.xl)
    .vfScreenBackground()
}

#Preview("진행 표시 · AccessibilityXXXL") {
    VFStepProgress(titles: RecordCreateStep.allCases.map(\.accessibilityTitle), currentIndex: 0)
        .padding(VFSpacing.xl)
        .vfScreenBackground()
        .environment(\.dynamicTypeSize, .accessibility5)
}
