import SwiftUI

/// Record Create 1단계 구장 시트의 순수 선택 계약.
///
/// 현재 초안은 읽기만 하고, 행을 명시적으로 고를 때만 호출부가 준 단 하나의 쓰기
/// 경계를 연다. 주 관람 구장·온보딩·기존 기록에는 접근하지 않는다.
struct RecordCreateStadiumSelection {
    let catalog: [KBOStadium]
    let selectedStadiumID: String?

    init(catalog: [KBOStadium], currentDraftName: String) {
        self.catalog = catalog
        selectedStadiumID = KBOStadiumSeed.id(forStoredName: currentDraftName)
    }

    /// 안정 ID가 현재 목록에 있고 canonical 등록부에도 있을 때만 전체 이름을 한 번 쓴다.
    func commit(stadiumID: String, write: (String) -> Void) {
        guard catalog.contains(where: { $0.id == stadiumID }),
              let canonical = KBOStadiumSeed.stadium(id: stadiumID) else { return }
        write(canonical.name)
    }
}

/// Pencil `09_States / 구장 바텀시트`(`Hmdjx`)의 보이는 구성.
///
/// `EXPLICIT_PRODUCT_DECISION: HMDJX_RECORD_CREATE_STEP1_STADIUM_SELECTOR`
///
/// Pencil은 표면·제목·행·선택 강조만 소유한다. Record Create 1단계에서 열고, 안정 ID
/// 선택을 현재 초안에 즉시 반영한 뒤 닫는 동작은 감사 뒤 승인된 제품 결정이다.
struct StadiumSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selection: RecordCreateStadiumSelection
    let onCommit: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: VFSpacing.xxs) {
                Text("구장을 선택해 주세요")
                    .font(VFTypography.sectionTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("stadiumSheet.title")
                    .padding(.horizontal, VFSpacing.xl)
                    .padding(.top, VFSpacing.md)
                    .padding(.bottom, VFSpacing.xs)

                if selection.catalog.isEmpty {
                    emptyState
                } else {
                    ForEach(selection.catalog) { stadium in
                        stadiumRow(stadium)
                    }
                }
            }
            .padding(.bottom, VFSpacing.xxl)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stadiumSheet.root")
        }
        .background(VFColor.elevatedSurface)
        .presentationBackground(VFColor.elevatedSurface)
        .presentationCornerRadius(VFRadius.sheet)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .overlay(alignment: .topLeading) { fixtureMarker }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("선택할 수 있는 구장이 없어요")
                .font(VFTypography.cardTitle)
                .foregroundStyle(VFColor.bodyPrimary)
            Text("시트를 내려 기록 작성으로 돌아갈 수 있어요.")
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VFSpacing.xl)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(VFColor.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .padding(.horizontal, VFSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stadiumSheet.empty")
    }

    private func stadiumRow(_ stadium: KBOStadium) -> some View {
        let isSelected = selection.selectedStadiumID == stadium.id
        return Button {
            selection.commit(stadiumID: stadium.id, write: onCommit)
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: VFSpacing.sm) {
                VFHomePlateGlyph(tint: VFColor.supportAccent)
                    .frame(width: 24, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stadium.shortName)
                        .font(Font.system(.subheadline, design: .default).weight(isSelected ? .bold : .medium))
                        .foregroundStyle(VFColor.bodyPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stadium.selectionSecondaryText)
                        .font(VFTypography.badge)
                        .foregroundStyle(VFColor.bodyTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: VFIconSize.medium, weight: .bold))
                        .foregroundStyle(VFColor.primaryActionDeep)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, VFSpacing.xl)
            .padding(.vertical, VFSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(isSelected ? VFColor.highlightSurface : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stadium.name)
        .accessibilityValue(
            [stadium.selectionSecondaryText, isSelected ? "선택됨" : nil]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("stadiumSheet.stadium.\(stadium.id)")
    }

    @ViewBuilder
    private var fixtureMarker: some View {
        if let identifier = VFUITestConfiguration.activeStadiumSheetScenarioIdentifier {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(Text(verbatim: ""))
        }
    }
}
