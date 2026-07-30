import SwiftUI

// Pencil `04_Home_Default_TeamSelected`가 쓰는 재사용 컴포넌트.
// 모두 표시용 값만 받고, 네트워크·저장소·통계 계산을 하지 않는다.

// MARK: - 어두운 표면 위의 팀 색

extension Color {
    /// 남색 표면 위에서도 읽히도록 팀 색을 밝은 쪽으로 옮긴 변형.
    ///
    /// Pencil은 삼성(#1E63C4) 이니셜을 #7FB2F5로 밝혀 쓴다. 팀마다 값을 따로 적어두는
    /// 대신 같은 규칙으로 유도해, 열 개 팀 모두 어두운 카드 위에서 대비를 확보한다.
    var vfOnDarkVariant: Color {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        // 흰색과 섞어 밝기를 올린다. 색상은 유지되므로 팀별 구분이 남는다.
        let blend: CGFloat = 0.55
        return Color(
            red: Double(red + (1 - red) * blend),
            green: Double(green + (1 - green) * blend),
            blue: Double(blue + (1 - blue) * blend)
        )
        #else
        return self
        #endif
    }
}

// MARK: - 팀 아이덴티티 헤더

/// Pencil `TeamIdentityHeader`. 응원 팀을 화면 위쪽에서 바로 알아보게 한다.
///
/// 팀 색만으로 구분하지 않는다. 레일·심볼·이름·"응원 중" 칩이 함께 정체성을 만든다.
struct VFTeamIdentityHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let team: KBOTeam
    /// 이번 시즌 전적 문구. 계산은 밖에서 끝내고 문자열만 받는다.
    var seasonRecordText: String?
    /// 사용자의 주 관람 구장. 특정 경기의 구장과 다르다.
    var primaryStadium: KBOStadium?

    private var accent: Color { team.accentColor }

    private var metaText: String {
        var parts = ["나의 팀"]
        if let seasonRecordText, !seasonRecordText.isEmpty { parts.append(seasonRecordText) }
        if let primaryStadium { parts.append("주 관람 \(primaryStadium.shortName)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // 접근성 글자 크기에서는 가로 한 줄에 다 들어가지 않는다.
                // 잘라내는 대신 세로로 접어 팀 이름과 "응원 중"을 온전히 남긴다.
                VStack(alignment: .leading, spacing: VFSpacing.sm) {
                    HStack(spacing: VFSpacing.sm) {
                        teamRail
                        teamSymbol
                    }
                    teamText
                    followChip
                }
            } else {
                HStack(spacing: VFSpacing.sm) {
                    teamRail
                    teamSymbol
                    teamText
                    Spacer(minLength: VFSpacing.xs)
                    followChip
                }
            }
        }
        .padding(.horizontal, VFSpacing.md)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 74)
        .background(VFColor.nightSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("나의 팀 \(team.name)")
        .accessibilityValue(metaText)
        .accessibilityIdentifier("home.teamIdentity")
    }

    // MARK: 조각

    private var teamRail: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(accent)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
            .frame(minHeight: 44)
            .accessibilityHidden(true)
    }

    /// Pencil `TeamIdentityHeader`의 `팀 페어리` — `TeamFairy48` 48×48.
    ///
    /// 예전에는 팀 약칭을 원 안에 넣었지만, 개정 원본은 이 자리에 팀 페어리를 둔다.
    /// 팀 정체성은 페어리 하나에 기대지 않는다 — 레일·팀 이름·"응원 중" 칩이 함께
    /// 말하고, 페어리는 그 위에 얹는 브랜드 표식이다.
    ///
    /// VoiceOver에서는 숨긴다. 이 헤더가 이미 팀 이름을 한 번 읽어 주므로,
    /// 페어리까지 읽으면 같은 팀을 두 번 말하게 된다.
    private var teamSymbol: some View {
        VFTeamFairy(teamID: team.id, size: .compact)
            .frame(width: VFTeamFairySize.compact.canvas, height: VFTeamFairySize.compact.canvas)
            .accessibilityIdentifier("home.teamFairy")
            .accessibilityHidden(true)
    }

    /// 팀 이름과 메타는 필수 정보라 어떤 글자 크기에서도 자르지 않는다.
    private var teamText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(team.name)
                .font(Font.system(.callout, design: .default).weight(.heavy))
                .foregroundStyle(VFColor.bodyOnDark)
                .fixedSize(horizontal: false, vertical: true)
            Text(metaText)
                .font(Font.system(.caption2, design: .default).weight(.medium))
                .foregroundStyle(VFColor.bodyOnDark.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 응원 중 칩. 색만이 아니라 별 아이콘과 글자로도 상태를 알리므로 글자를 자르지 않는다.
    private var followChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
            Text("응원 중")
                .font(Font.system(.caption2, design: .default).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(VFColor.primaryAction)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(VFColor.primaryAction.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - 구장 스트립

/// Pencil `구장 스트립`(MatchupCard 내부). 경기가 열린 구장을 카드 안에서 한 줄로 보여준다.
struct VFStadiumGameStrip: View {
    /// 표시할 구장 이름. 등록된 구장이면 `stadium`이 함께 온다.
    let stadiumName: String
    var stadium: KBOStadium?
    var trailingNote: String?
    var onTap: (() -> Void)?

    private var label: String {
        guard let trailingNote, !trailingNote.isEmpty else { return stadiumName }
        return "\(stadiumName) · \(trailingNote)"
    }

    var body: some View {
        let content = HStack(spacing: VFSpacing.xs) {
            VFHomePlateGlyph()
                .frame(width: 14, height: 13)
                .accessibilityHidden(true)
            Text(label)
                .font(Font.system(.caption, design: .default).weight(.bold))
                .foregroundStyle(VFColor.fieldLabel)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VFColor.nightTertiary)
            }
        }
        .padding(.horizontal, VFSpacing.sm)
        .padding(.vertical, VFSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))

        Group {
            if let onTap {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("경기 구장 \(stadiumName)")
        .accessibilityIdentifier("home.gameStadium")
    }
}

/// Pencil `Glyph_HomePlate`. 홈 플레이트 오각형.
struct VFHomePlateGlyph: View {
    var tint: Color = VFColor.fieldMark

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                path.move(to: CGPoint(x: w * 0.08, y: 0))
                path.addLine(to: CGPoint(x: w * 0.92, y: 0))
                path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.52))
                path.addLine(to: CGPoint(x: w * 0.5, y: h))
                path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.52))
                path.closeSubpath()
            }
            .fill(tint)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 매치업 히어로 카드

/// Pencil `MatchupCard_Expanded`.
///
/// Pencil 원본은 "오늘 경기"를 보여주지만 홈에는 예정 경기 데이터원이 없다.
/// 그래서 이 카드는 **실제로 있는 값**만 받는다. 상태 문구·점수·구장 모두 호출부가
/// 실제 기록에서 만들어 넘긴다. 값을 지어내지 않는다.
struct VFMatchupHeroCard: View {
    struct Side: Equatable {
        let team: KBOTeam?
        /// 팀을 찾지 못했을 때 쓸 원본 표기.
        let fallbackLabel: String
        /// "홈 · 나의 팀"처럼 역할을 설명하는 짧은 문구.
        let role: String
        /// 사용자의 응원 팀이면 역할 문구를 금색으로 강조한다.
        let isFavorite: Bool

        var displayName: String { team?.shortName ?? fallbackLabel }
        var accent: Color { team?.accentColor ?? VFColor.bodyTertiary }
        var initial: String { team?.badgeInitial ?? String(fallbackLabel.prefix(2)) }
    }

    let statusTitle: String
    var statusTint: Color = VFColor.primaryAction
    let dateText: String
    let leading: Side
    let trailing: Side
    /// 가운데 큰 글자. 스코어나 시작 시각처럼 실제로 아는 값만 넣는다.
    let centerText: String
    var centerSubtitle: String?
    var stadiumName: String?
    var stadium: KBOStadium?
    var stadiumNote: String?
    var onStadiumTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                statusBadge
                Spacer(minLength: VFSpacing.xs)
                Text(dateText)
                    .font(Font.system(.subheadline, design: .default).weight(.semibold).monospacedDigit())
                    .foregroundStyle(VFColor.bodyOnDark.opacity(0.6))
                    .lineLimit(1)
            }

            matchupRow

            if let stadiumName {
                VFStadiumGameStrip(
                    stadiumName: stadiumName,
                    stadium: stadium,
                    trailingNote: stadiumNote,
                    onTap: onStadiumTap
                )
            }
        }
        .padding(VFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [VFColor.heroGradientTop, VFColor.heroGradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous)
                .stroke(VFColor.nightHairline, lineWidth: 1)
        )
        .shadow(color: VFColor.nightSurface.opacity(0.25), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.matchupHero")
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusTint)
                .frame(width: 6, height: 6)
            Text(statusTitle)
                .font(Font.system(.caption2, design: .default).weight(.bold))
                .foregroundStyle(statusTint)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(statusTint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusTitle)
    }

    /// 접근성 글자 크기에서는 좌우 배치가 좁아지므로 세로로 접는다.
    private var matchupRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: VFSpacing.xs) {
                sideColumn(leading)
                centerColumn
                sideColumn(trailing)
            }
            VStack(spacing: VFSpacing.sm) {
                centerColumn
                HStack(alignment: .top, spacing: VFSpacing.sm) {
                    sideColumn(leading)
                    sideColumn(trailing)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func sideColumn(_ side: Side) -> some View {
        VStack(spacing: 6) {
            Text(side.initial)
                .font(Font.system(size: side.initial.count > 1 ? 15 : 20, weight: .heavy))
                .foregroundStyle(side.accent.vfOnDarkVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 54, height: 54)
                .background(side.accent.opacity(0.15))
                .clipShape(Circle())
                .overlay(Circle().stroke(side.accent, lineWidth: 2.5))

            Text(side.displayName)
                .font(Font.system(.subheadline, design: .default).weight(.heavy))
                .foregroundStyle(VFColor.bodyOnDark)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(side.role)
                .font(Font.system(.caption2, design: .default).weight(.semibold))
                .foregroundStyle(side.isFavorite ? VFColor.primaryAction : VFColor.bodyOnDark.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(side.team?.name ?? side.fallbackLabel), \(side.role)")
    }

    private var centerColumn: some View {
        VStack(spacing: 2) {
            Text(centerText)
                .font(Font.system(size: 40, weight: .bold).monospacedDigit())
                .foregroundStyle(VFColor.bodyOnDark)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let centerSubtitle, !centerSubtitle.isEmpty {
                Text(centerSubtitle)
                    .font(Font.system(.caption2, design: .default).weight(.semibold))
                    .foregroundStyle(VFColor.bodyOnDark.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(centerSubtitle.map { "\(centerText), \($0)" } ?? centerText)
    }
}

// MARK: - 시즌 스트립

/// Pencil `시즌 스트립`. 남색 바탕에 시즌 요약 수치 세 칸.
struct VFSeasonStrip: View {
    struct Cell: Identifiable, Equatable {
        var id: String { label }
        let value: String
        let label: String
    }

    let cells: [Cell]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: VFSpacing.xs) { content }
            VStack(spacing: VFSpacing.sm) { content }
        }
        .padding(.horizontal, VFSpacing.xs)
        .padding(.vertical, VFSpacing.sm)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 86)
        .background(VFColor.nightSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.seasonStrip")
    }

    @ViewBuilder
    private var content: some View {
        ForEach(cells) { cell in
            VStack(spacing: VFSpacing.xxs) {
                Text(cell.value)
                    .font(Font.system(.title2, design: .default).weight(.bold).monospacedDigit())
                    .foregroundStyle(VFColor.bodyOnDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(cell.label)
                    .font(Font.system(.caption2, design: .default))
                    .foregroundStyle(VFColor.bodyOnDark.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(cell.label) \(cell.value)")
        }
    }
}
