import SwiftUI

/// 마이 화면의 **응원 팀 변경** 시트.
///
/// 이 화면은 온보딩과 아무 관계가 없다. 온보딩은 `OnboardingTeamStepView`와
/// `OnboardingTeamCard`로 자기 단계를 따로 그린다. 이 파일이 `Features/Onboarding`
/// 아래 있는 것은 옛 위치일 뿐이고, 옮기는 일은 이 동작 패스에 섞지 않는다.
///
/// Pencil은 이 시트를 그리지 않았다. 레이아웃은 승인된 제품 명세이며,
/// 팀 카드 언어만 이미 있는 것을 그대로 쓴다.
///
/// **초안을 먼저 쥐고, 완료에서 한 번만 커밋한다.** 예전에는 선택이 곧바로
/// `updateFavoriteTeam`으로 흘러 들어가, 취소해도 이미 팀이 바뀌어 있었고
/// `선택 안 함`을 누르면 응원 팀이 지워져 온보딩 복구 경로로 튕겼다.
struct TeamSelectionView: View {
    let teams: [KBOTeam]
    let initialSelectedTeamID: String?
    /// 사용자가 완료를 눌렀고, 값이 실제로 바뀌었을 때만 불린다.
    let onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var draftSelectedTeamID: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: VFSpacing.sm)]

    init(teams: [KBOTeam], initialSelectedTeamID: String?, onCommit: @escaping (String) -> Void) {
        self.teams = teams
        self.initialSelectedTeamID = initialSelectedTeamID
        self.onCommit = onCommit
        // 저장된 값이 지금 목록에서 풀리지 않으면 아무것도 고르지 않은 채로 연다.
        // 조용히 고쳐 쓰지 않는다 — 무엇을 고를지는 사용자가 정한다.
        let resolved = teams.contains { $0.id == initialSelectedTeamID } ? initialSelectedTeamID : nil
        _draftSelectedTeamID = State(initialValue: resolved)
    }

    /// 완료할 수 있는가. 유효한 초안이 있어야만 커밋할 수 있다.
    private var committableTeamID: String? {
        guard let draftSelectedTeamID,
              teams.contains(where: { $0.id == draftSelectedTeamID }) else { return nil }
        return draftSelectedTeamID
    }

    var body: some View {
        Group {
            if teams.isEmpty {
                emptyCatalog
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: VFSpacing.sm) {
                        ForEach(teams) { team in
                            Button {
                                // 초안만 바뀐다. canonical 상태는 완료에서만 움직인다.
                                draftSelectedTeamID = team.id
                            } label: {
                                TeamSelectionCard(team: team,
                                                  isSelected: draftSelectedTeamID == team.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(accessibilityLabel(for: team))
                            .accessibilityAddTraits(draftSelectedTeamID == team.id ? .isSelected : [])
                            .accessibilityIdentifier("teamSelection.team.\(team.id)")
                        }
                    }
                    .padding(VFSpacing.lg)
                }
            }
        }
        .accessibilityIdentifier("teamSelection.root")
        .navigationTitle("응원 팀 변경")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
                    .foregroundStyle(theme.primary)
                    .accessibilityIdentifier("teamSelection.cancel")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("완료") { complete() }
                    .foregroundStyle(theme.primary)
                    .disabled(committableTeamID == nil)
                    .accessibilityIdentifier("teamSelection.done")
            }
        }
        .vfScreenBackground()
    }

    /// 완료. 값이 그대로면 굳이 쓰지 않는다.
    private func complete() {
        guard let committableTeamID else { return }
        if committableTeamID != initialSelectedTeamID {
            onCommit(committableTeamID)
        }
        dismiss()
    }

    private var emptyCatalog: some View {
        VStack(spacing: VFSpacing.sm) {
            Text("보여 줄 팀이 없어요")
                .font(VFTypography.sectionTitle)
                .foregroundStyle(VFColor.bodyPrimary)
            Text("팀 목록을 불러오지 못했어요. 잠시 뒤 다시 열어 주세요.")
                .font(.subheadline)
                .foregroundStyle(VFColor.bodySecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VFSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("teamSelection.empty")
    }

    private func accessibilityLabel(for team: KBOTeam) -> String {
        let suffix = draftSelectedTeamID == team.id ? ", 선택됨" : ""
        return "\(team.name), \(team.city), 홈구장 \(team.homeStadiumName)\(suffix)"
    }
}

private struct TeamSelectionCard: View {
    let team: KBOTeam
    let isSelected: Bool

    private var primaryColor: Color { team.accentColor }
    private var secondaryColor: Color { VFColor.deepAccent }

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

#Preview("응원 팀 변경") {
    NavigationStack {
        TeamSelectionView(teams: KBOSeed.teams,
                          initialSelectedTeamID: "lg-twins") { _ in }
    }
}

#Preview("응원 팀 변경 · 빈 목록") {
    NavigationStack {
        TeamSelectionView(teams: [], initialSelectedTeamID: nil) { _ in }
    }
}
