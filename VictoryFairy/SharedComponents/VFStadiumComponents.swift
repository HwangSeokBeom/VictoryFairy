import SwiftUI

// Pencil이 구장을 다루는 방식. 구장은 더 이상 회색 메타데이터가 아니라
// 고유한 그래픽을 가진 1급 요소다.

// MARK: - 브랜드 마크

/// 런치 스크린과 같은 V + 야구공 마크.
/// 자산 카탈로그의 벡터를 그대로 재사용해 런치 화면과 앱 안이 어긋나지 않게 한다.
struct VFBrandMark: View {
    var height: CGFloat = 80

    var body: some View {
        Image("LaunchMark")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - 구장 글리프

/// Pencil `VenueGlyph_*`에 대응하는 구장 그래픽.
///
/// 저장소에 구장별 실제 일러스트 자산이 없으므로, Pencil이 안내한 대로 야간 조명과
/// 필드 곡선을 쓴 **추상 모티프**로 구장을 구분한다. 실제 구장을 그린 그림이 아니며
/// 그렇게 보이도록 꾸미지 않는다. 구장마다 필드 곡률과 조명 배치를 달리해 시각적으로
/// 구별되게 한다.
struct VFStadiumGlyph: View {
    let stadiumID: String
    var cornerRadius: CGFloat = VFRadius.sm

    private var stadium: KBOStadium? { KBOStadiumSeed.stadium(id: stadiumID) }

    /// 홈 팀의 강조색으로 필드를 물들여 구장끼리 확실히 구분되게 한다.
    /// 잠실처럼 두 팀이 쓰는 구장은 첫 번째 홈 팀 색을 기준으로 삼는다.
    private var fieldTint: Color {
        VFTeamAccent.color(forTeamID: stadium?.homeTeamIDs.first)
    }

    private var isDome: Bool {
        // 고척은 돔이라 지붕 곡선을 닫아 그린다.
        stadiumID == "gocheok"
    }

    /// 구장 ID에서 안정적으로 유도한 필드 곡률. 무작위가 아니라 항상 같은 모양이다.
    private var curvature: Double {
        let index = KBOStadiumSeed.all.firstIndex { $0.id == stadiumID } ?? 0
        return 0.26 + Double(index % 4) * 0.06
    }

    var body: some View {
        ZStack {
            VFColor.nightSurface

            // 홈 팀 색으로 물든 필드 불빛
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [fieldTint.opacity(0.55), .clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: 40
                    )
                )

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                // 필드 곡선. 구장마다 곡률이 다르다.
                Path { path in
                    let baseline = h * 0.86
                    path.move(to: CGPoint(x: w * 0.04, y: baseline))
                    path.addQuadCurve(
                        to: CGPoint(x: w * 0.96, y: baseline),
                        control: CGPoint(x: w * 0.5, y: baseline - h * curvature)
                    )
                    path.addLine(to: CGPoint(x: w * 0.96, y: h))
                    path.addLine(to: CGPoint(x: w * 0.04, y: h))
                    path.closeSubpath()
                }
                .fill(fieldTint.opacity(0.75))

                // 돔이면 지붕을 덮는다.
                if isDome {
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.06, y: h * 0.60))
                        path.addQuadCurve(
                            to: CGPoint(x: w * 0.94, y: h * 0.60),
                            control: CGPoint(x: w * 0.5, y: h * 0.02)
                        )
                    }
                    .stroke(VFColor.primaryAction, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                } else {
                    // 지붕이 열린 구장은 조명탑을 세운다.
                    ForEach(0..<2, id: \.self) { index in
                        let x = index == 0 ? w * 0.20 : w * 0.80
                        Path { path in
                            path.move(to: CGPoint(x: x, y: h * 0.26))
                            path.addLine(to: CGPoint(x: x, y: h * 0.70))
                        }
                        .stroke(VFColor.nightHairline, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(VFColor.primaryAction)
                            .frame(width: w * 0.22, height: max(3, h * 0.10))
                            .position(x: x, y: h * 0.22)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - 구장 뱃지

/// Pencil `StadiumBadge_Compact`. 목록·카드 안에서 구장을 한 줄로 보여준다.
struct VFStadiumBadge: View {
    let stadium: KBOStadium
    var showsCity = false

    var body: some View {
        HStack(spacing: 6) {
            VFStadiumGlyph(stadiumID: stadium.id, cornerRadius: 5)
                .frame(width: 22, height: 20)
            Text(showsCity ? "\(stadium.shortName) · \(stadium.city)" : stadium.shortName)
                .font(Font.system(.caption, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VFColor.subtleSurface)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stadium.name)
    }
}

// MARK: - 구장 히어로

/// Pencil `StadiumHero`. 홈 상단에서 주 관람 구장을 크게 보여준다.
struct VFStadiumHero: View {
    let stadium: KBOStadium
    var team: KBOTeam?
    var caption: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VFStadiumGlyph(stadiumID: stadium.id, cornerRadius: VFRadius.card)

            LinearGradient(
                colors: [.clear, VFColor.nightSurface.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                if let team {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(team.accentColor)
                            .frame(width: 8, height: 8)
                        Text(team.name)
                            .font(Font.system(.caption, design: .default).weight(.bold))
                            .foregroundStyle(VFColor.bodyOnDark.opacity(0.85))
                    }
                }
                Text(stadium.name)
                    .font(Font.system(.title3, design: .default).weight(.heavy))
                    .foregroundStyle(VFColor.bodyOnDark)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let caption {
                    Text(caption)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyOnDark.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(VFSpacing.sm)
        }
        .frame(minHeight: 116)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([team?.name, stadium.name, caption].compactMap { $0 }.joined(separator: ", "))
    }
}

#Preview("구장 컴포넌트") {
    ScrollView {
        VStack(alignment: .leading, spacing: VFSpacing.md) {
            VFStadiumHero(
                stadium: KBOStadiumSeed.all[0],
                team: KBOSeed.teams[0],
                caption: "주 관람 구장"
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: VFSpacing.xs)], spacing: VFSpacing.xs) {
                ForEach(KBOStadiumSeed.all) { stadium in
                    VStack(spacing: 4) {
                        VFStadiumGlyph(stadiumID: stadium.id)
                            .frame(width: 72, height: 56)
                        Text(stadium.shortName)
                            .font(VFTypography.metadata)
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                }
            }
            ForEach(KBOStadiumSeed.all.prefix(3)) { stadium in
                VFStadiumBadge(stadium: stadium, showsCity: true)
            }
        }
        .padding(VFSpacing.md)
    }
    .vfScreenBackground()
}
