import SwiftUI

struct TeamSelectionView: View {
    @Binding var selectedTeamID: String?
    var teams: [KBOTeam] = KBOSeed.teams
    var title = "응원팀을 선택해 주세요"
    var subtitle = "선택한 팀 컬러가 앱 테마에 반영돼요."
    var footnote = "나중에 설정에서 변경할 수 있어요."
    var showsNeutralOption = true

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: VFSpacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.lg) {
            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                Text(title)
                    .font(VFTypography.sectionTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(VFColor.bodySecondary)
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)
            }

            LazyVGrid(columns: columns, spacing: VFSpacing.sm) {
                if showsNeutralOption {
                    neutralCard
                }

                ForEach(teams) { team in
                    Button {
                        selectedTeamID = team.id
                    } label: {
                        TeamSelectionCard(team: team, isSelected: selectedTeamID == team.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: team))
                }
            }
        }
    }

    private var neutralCard: some View {
        Button {
            selectedTeamID = nil
        } label: {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                HStack {
                    Text("선택 안 함")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(VFColor.bodyPrimary)
                    Spacer()
                    if selectedTeamID == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(VFColor.supportAccent)
                            .accessibilityHidden(true)
                    }
                }
                Text("기본 테마 사용")
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)
                Text(selectedTeamID == nil ? "선택됨" : "기본")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(selectedTeamID == nil ? VFColor.supportAccent : VFColor.bodySecondary)
            }
            .padding(VFSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .background(VFColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                    .stroke(selectedTeamID == nil ? VFColor.supportAccent : VFColor.hairline, lineWidth: selectedTeamID == nil ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedTeamID == nil ? "선택 안 함, 기본 테마 사용, 선택됨" : "선택 안 함, 기본 테마 사용")
    }

    private func accessibilityLabel(for team: KBOTeam) -> String {
        let suffix = selectedTeamID == team.id ? ", 선택됨" : ""
        return "\(team.name), \(team.city), 홈구장 \(team.homeStadiumName)\(suffix)"
    }
}

private struct TeamSelectionCard: View {
    let team: KBOTeam
    let isSelected: Bool

    private var primaryColor: Color { Color(hex: team.primaryColorHex) }
    private var secondaryColor: Color { Color(hex: team.secondaryColorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                    Text(team.shortName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(primaryColor)
                    Text(team.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(VFColor.bodyPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? primaryColor : VFColor.bodySecondary.opacity(0.55))
                    .accessibilityHidden(true)
            }

            Text("\(team.city) · \(team.homeStadiumName)")
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            HStack(spacing: VFSpacing.xs) {
                Capsule()
                    .fill(primaryColor)
                    .frame(width: 28, height: 8)
                Capsule()
                    .fill(secondaryColor)
                    .frame(width: 28, height: 8)
                Spacer()
                Text(isSelected ? "선택됨" : "선택")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? primaryColor : VFColor.bodySecondary)
            }
        }
        .padding(VFSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(isSelected ? primaryColor : VFColor.hairline, lineWidth: isSelected ? 2 : 1)
        )
    }
}

#Preview("팀 선택 없음") {
    ScrollView {
        TeamSelectionView(selectedTeamID: .constant(nil))
            .padding(VFSpacing.lg)
    }
    .vfScreenBackground()
}

#Preview("팀 선택 LG") {
    ScrollView {
        TeamSelectionView(selectedTeamID: .constant("lg-twins"))
            .padding(VFSpacing.lg)
    }
    .environment(\.appTheme, TeamTheme(team: KBOSeed.teams[0]))
    .vfScreenBackground()
}
