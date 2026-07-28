import SwiftUI

// Pencil `컴포넌트 시스템` 프레임의 재사용 컴포넌트를 그대로 옮긴 것.
//
// 모든 컴포넌트는 의미 있는 데이터만 받는다. 팀 이름·스코어·날짜 같은 예시 값을
// 안에 넣어두지 않으며, 네트워크나 저장소에도 접근하지 않는다.
//
// 높이는 Pencil 값을 최소 높이로 쓴다. Dynamic Type이 커지면 세로로 자라야 하므로
// 고정 높이를 쓰지 않는다.

// MARK: - 카드

/// Pencil 기본 카드. 종이 위에 한 겹 올라온 표면.
struct VFCard<Content: View>: View {
    var padding: CGFloat
    var background: Color
    var cornerRadius: CGFloat
    @ViewBuilder var content: Content

    init(
        padding: CGFloat = VFSpacing.md,
        background: Color = VFColor.elevatedSurface,
        cornerRadius: CGFloat = VFRadius.card,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.background = background
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
            )
            .shadow(color: VFShadow.cardColor, radius: VFShadow.cardRadius, y: VFShadow.cardOffsetY)
    }
}

// MARK: - 버튼

/// Pencil `버튼/프라이머리`. 산호색 바탕에 잉크 윤곽선을 두른 주요 액션.
struct VFPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: VFSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(VFTypography.button)
                }
                Text(title)
                    .font(VFTypography.button)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(VFColor.bodyOnDark)
            .padding(.horizontal, VFSpacing.md)
            .padding(.vertical, VFSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: VFControl.buttonHeight)
            .background(isEnabled ? VFColor.primaryAction : VFColor.disabled)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous)
                    .stroke(VFColor.inkOutline, lineWidth: VFStroke.ink)
            )
            .shadow(color: VFShadow.buttonColor, radius: VFShadow.buttonRadius, y: VFShadow.buttonOffsetY)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}

/// Pencil `버튼/세컨더리`. 같은 형태에 종이색 바탕.
struct VFSecondaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: VFSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(VFTypography.button)
                }
                Text(title)
                    .font(Font.system(.callout, design: .default).weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(VFColor.bodyPrimary)
            .padding(.horizontal, VFSpacing.md)
            .padding(.vertical, VFSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: VFControl.buttonHeight)
            .background(VFColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous)
                    .stroke(VFColor.inkOutline, lineWidth: VFStroke.ink)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - 칩

/// Pencil `칩`. 필터·태그에 쓰는 작은 알약.
///
/// 선택 상태는 Pencil 기록 피드의 `칩 전체`를 따른다. 잉크색 바탕에 종이색 글자라
/// 선택 여부가 색 대비만으로도 뚜렷하다.
struct VFChip: View {
    let title: String
    var isSelected = false
    /// 선택 시 바탕색. 비우면 Pencil 기본값인 잉크색.
    var tint: Color?

    var body: some View {
        let selectedFill = tint ?? VFColor.bodyPrimary
        Text(title)
            .font(Font.system(.footnote, design: .default).weight(isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? selectedFill.vfReadableForegroundColor : VFColor.bodySecondary)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .frame(minHeight: 32)
            .background(isSelected ? selectedFill : VFColor.subtleSurface)
            .clipShape(Capsule())
    }
}

/// Pencil 피드 헤더의 `기록 추가` 버튼. 산호색 원에 잉크 윤곽선.
struct VFProminentIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: VFIconSize.large, weight: .semibold))
                .foregroundStyle(VFColor.bodyOnDark)
                .frame(width: VFControl.minimumTouchTarget, height: VFControl.minimumTouchTarget)
                .background(VFColor.primaryAction)
                .clipShape(Circle())
                .overlay(Circle().stroke(VFColor.inkOutline, lineWidth: 1.4))
                .shadow(color: VFShadow.buttonColor, radius: VFShadow.buttonRadius, y: VFShadow.buttonOffsetY)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Pencil 피드의 월 구분 헤더. 손글씨 월 라벨 옆으로 가는 선이 이어진다.
struct VFMonthDivider: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(VFTypography.handwrittenLarge)
                .foregroundStyle(VFColor.bodySecondary)
            Rectangle()
                .fill(VFColor.hairline)
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 팀 뱃지

/// Pencil `팀 뱃지`. 종이색 원에 팀 강조색 테두리와 약칭을 넣는다.
///
/// 저장소에는 구단 로고 에셋이 없고 Pencil도 로고 대신 약칭 표기를 쓰므로,
/// 글자 기반 표현이 원본과 일치한다.
struct VFTeamBadge: View {
    let team: KBOTeam?
    var size: CGFloat = VFControl.teamBadgeSize
    /// 팀을 알 수 없을 때 보여줄 글자.
    var fallbackInitial = "?"

    @ScaledMetric(relativeTo: .caption2) private var scaleFactor: CGFloat = 1

    var body: some View {
        let initial = team?.badgeInitial ?? fallbackInitial
        let accent = team.map { VFTeamAccent.color(forTeamID: $0.id) } ?? VFColor.bodyTertiary
        let resolvedSize = size * scaleFactor

        Text(initial)
            .font(Font.system(size: initial.count > 1 ? 9 : 13, weight: .bold))
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .foregroundStyle(accent)
            .frame(width: resolvedSize, height: resolvedSize)
            .background(VFColor.elevatedSurface)
            .clipShape(Circle())
            .overlay(Circle().stroke(accent, lineWidth: VFStroke.badge))
            .accessibilityLabel(team?.name ?? "팀 미정")
    }
}

// MARK: - 결과 스탬프

/// Pencil `스탬프/승·패·무`. 결과색으로 꽉 채운 원 안에 흰 글자.
///
/// 최신 Pencil에서 손으로 찍은 듯한 이중 링과 기울기가 사라지고, 단색 원 하나로
/// 정리됐다. 색만으로 결과를 구분하지 않는다는 원칙은 그대로다. 승·패·무 글자 자체가
/// 구분 수단이라 Differentiate Without Color 설정에서도 의미가 유지된다.
struct VFResultStamp: View {
    let result: GameResult
    var size: CGFloat = VFControl.stampSize

    @ScaledMetric(relativeTo: .body) private var scaleFactor: CGFloat = 1

    var body: some View {
        let resolvedSize = size * scaleFactor
        ZStack {
            Circle()
                .fill(result.color)
                .frame(width: resolvedSize * 42 / 46, height: resolvedSize * 42 / 46)
            Text(result.title)
                .font(Font.system(size: resolvedSize * 15 / 46, weight: .heavy))
                .foregroundStyle(VFColor.elevatedSurface)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: resolvedSize, height: resolvedSize)
        .accessibilityElement()
        .accessibilityLabel(result.diaryTitle)
    }
}

/// Pencil `StatusBadge`. 예정·진행 중처럼 결과가 아직 없는 경기 상태를 알린다.
struct VFStatusBadge: View {
    let title: String
    var tint: Color = VFColor.gameScheduled

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(title)
                .font(Font.system(.caption2, design: .default).weight(.bold))
                .foregroundStyle(VFColor.bodySecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(VFColor.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - 섹션 헤더

/// Pencil `섹션 헤더`. 제목과 선택적 "전체 보기" 링크.
struct VFSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: VFSpacing.sm) {
            Text(title)
                .font(VFTypography.sectionTitle)
                .foregroundStyle(VFColor.bodyPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: VFSpacing.xs)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                            .font(Font.system(.footnote, design: .default).weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(VFColor.bodyTertiary)
                    .frame(minHeight: VFControl.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) \(actionTitle)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 메타 행

/// Pencil `메타 행`. 아이콘 하나와 짧은 설명.
struct VFMetaRow: View {
    let systemImage: String
    let text: String
    /// VoiceOver에서 읽을 문장. 비우면 텍스트를 그대로 읽는다.
    var accessibilityText: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: VFIconSize.small, weight: .medium))
                .foregroundStyle(VFColor.bodyTertiary)
            Text(text)
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText ?? text)
    }
}

// MARK: - 폼 필드

/// Pencil `폼 필드`. 라벨과 입력 박스가 세로로 붙은 형태.
struct VFFormField<Content: View>: View {
    let label: String
    var errorMessage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(Font.system(.footnote, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)

            content
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: VFControl.fieldHeight, alignment: .leading)
                .background(errorMessage == nil ? VFColor.elevatedSurface : VFColor.primaryActionPale.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous)
                        .stroke(
                            errorMessage == nil ? VFColor.hairline : VFColor.primaryActionDeep,
                            lineWidth: errorMessage == nil ? VFStroke.field : 1.6
                        )
                )

            if let errorMessage {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 13, weight: .medium))
                    Text(errorMessage)
                        .font(VFTypography.metadata)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(VFColor.primaryActionDeep)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityValue(errorMessage ?? "")
    }
}

// MARK: - 토스트

/// Pencil `토스트`. 화면 하단에 잠깐 뜨는 알림.
struct VFToast: View {
    let message: String
    var systemImage: String = "checkmark"
    var tint: Color = VFColor.attentionAccent

    var body: some View {
        HStack(spacing: VFSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
            Text(message)
                .font(VFTypography.body)
                .foregroundStyle(VFColor.bodyOnDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, VFSpacing.sm)
        .background(VFColor.bodyPrimary.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sheet, style: .continuous))
        .shadow(color: VFShadow.overlayColor, radius: 16, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }
}

// MARK: - 테이프

/// Pencil 폴라로이드·공유 카드 위쪽에 붙는 마스킹 테이프 장식.
struct VFTapeStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var width: CGFloat = 64
    var tilt: Double = VFTilt.tape

    var body: some View {
        VFIllustrationView(.tape, height: width * 22 / 64)
            .vfTilt(tilt, reduceMotion: reduceMotion)
    }
}

// MARK: - 상태 패널

/// Pencil `상태와 피드백` 열 A의 빈 상태 패널.
struct VFEmptyStatePanel: View {
    let title: String
    let message: String
    var illustration: VFIllustration = .glove
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: VFSpacing.md) {
            VFIllustrationView(illustration, height: 56)

            Text(title)
                .font(VFTypography.sectionTitle)
                .foregroundStyle(VFColor.bodyPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Font.system(.subheadline, design: .default).weight(.bold))
                        .foregroundStyle(VFColor.bodyOnDark)
                        .padding(.horizontal, VFSpacing.lg)
                        .padding(.vertical, VFSpacing.sm)
                        .frame(minHeight: VFControl.minimumTouchTarget)
                        .background(VFColor.primaryAction)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                                .stroke(VFColor.inkOutline, lineWidth: 1.4)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, VFSpacing.xxl)
        .padding(.horizontal, VFSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .accessibilityElement(children: .contain)
    }
}

/// Pencil 로딩 패널. 야구공과 세 점이 순서대로 밝아진다.
struct VFLoadingPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var message: String = "불러오는 중이에요"
    @State private var activeDot = 0

    private let timer = Timer.publish(every: VFMotion.loadingCycle / 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: VFSpacing.sm) {
            VFIllustrationView(.baseball, height: 44)
                .vfTilt(35, reduceMotion: reduceMotion)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(VFColor.primaryAction)
                        .frame(width: 7, height: 7)
                        .opacity(opacity(for: index))
                }
            }
            .animation(VFMotion.respectingReduceMotion(.easeInOut(duration: 0.25), reduceMotion: reduceMotion), value: activeDot)

            Text(message)
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, VFSpacing.xl)
        .padding(.horizontal, VFSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            activeDot = (activeDot + 1) % 3
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Pencil은 점 세 개를 1 / 0.5 / 0.25 투명도로 그린다. 그 값을 순환시킨다.
    private func opacity(for index: Int) -> Double {
        guard !reduceMotion else { return [1, 0.5, 0.25][index] }
        let distance = (index - activeDot + 3) % 3
        return [1, 0.5, 0.25][distance]
    }
}

/// Pencil 오류 패널. 우천 중단에 빗댄 문구와 다시 시도 버튼.
struct VFErrorPanel: View {
    var title: String = "잠시 우천 중단이에요"
    var message: String
    var retryTitle: String = "다시 시도"
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: VFSpacing.sm) {
            VFIllustrationView(.rainCloud, height: 52)

            Text(title)
                .font(VFTypography.sectionTitle)
                .foregroundStyle(VFColor.bodyPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let onRetry {
                Button(action: onRetry) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text(retryTitle)
                            .font(Font.system(.footnote, design: .default).weight(.semibold))
                    }
                    .foregroundStyle(VFColor.bodyPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(minHeight: VFControl.minimumTouchTarget)
                    .background(VFColor.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous)
                            .stroke(VFColor.inkOutline, lineWidth: 1.4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, VFSpacing.xl)
        .padding(.horizontal, VFSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 프리뷰

#Preview("컴포넌트 시스템") {
    ScrollView {
        VStack(alignment: .leading, spacing: VFSpacing.lg) {
            VFSectionHeader(title: "섹션 제목", actionTitle: "전체 보기") {}
            VFPrimaryButton(title: "직관 기록하기")
            VFSecondaryButton(title: "나중에 할게요")
            HStack(spacing: VFSpacing.xs) {
                VFChip(title: "전체", isSelected: true)
                VFChip(title: "승")
                VFChip(title: "패")
            }
            HStack(spacing: VFSpacing.sm) {
                ForEach(KBOSeed.teams.prefix(5)) { team in
                    VFTeamBadge(team: team)
                }
            }
            HStack(spacing: VFSpacing.md) {
                ForEach(GameResult.allCases) { result in
                    VFResultStamp(result: result)
                }
            }
            VFMetaRow(systemImage: "mappin.and.ellipse", text: "잠실야구장")
            VFFormField(label: "스코어") {
                Text("우리 팀 점수")
                    .font(VFTypography.body)
                    .foregroundStyle(VFColor.bodyTertiary)
            }
            VFFormField(label: "스코어", errorMessage: "점수를 입력하면 승패를 자동으로 계산해요") {
                Text("우리 팀 점수")
                    .font(VFTypography.body)
                    .foregroundStyle(VFColor.bodyTertiary)
            }
            VFToast(message: "오늘의 직관이 저장됐어요")
        }
        .padding(VFSpacing.md)
    }
    .vfScreenBackground()
}

#Preview("상태 패널") {
    ScrollView {
        VStack(spacing: VFSpacing.lg) {
            VFEmptyStatePanel(
                title: "아직 직관 기록이 없어요",
                message: "첫 직관의 기억부터 차곡차곡 모아드릴게요.\n사진 한 장이면 충분해요.",
                actionTitle: "첫 기록 남기기"
            ) {}
            VFLoadingPanel(message: "경기 정보를 불러오는 중이에요")
            VFErrorPanel(message: "연결이 원활하지 않아요.\n네트워크를 확인하고 다시 시도해 주세요.") {}
        }
        .padding(VFSpacing.md)
    }
    .vfScreenBackground()
}

#Preview("열 팀 뱃지") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: VFSpacing.sm)], spacing: VFSpacing.md) {
            ForEach(KBOSeed.teams) { team in
                VStack(spacing: VFSpacing.xxs) {
                    VFTeamBadge(team: team)
                    Text(team.shortName)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .vfScreenBackground()
}
