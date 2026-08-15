import SwiftUI

// Pencil이 직관 기록을 보여주는 두 가지 카드.
//
// - `VFPolaroidCard`: 홈 "가장 최근의 직관". 사진을 크게 보여주는 폴라로이드.
// - `VFRecordCard`: 기록 피드의 티켓 반쪽 카드.
//
// 둘 다 표시용 상태만 받고 네트워크나 저장소에 직접 접근하지 않는다.

// MARK: - 폴라로이드 카드

/// Pencil 홈 `폴라로이드 카드`. 사진 위에 마스킹 테이프를 붙인 형태.
struct VFPolaroidCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let log: AttendanceLogViewState
    /// 사진 영역 높이. Pencil 기본값 196.
    var photoHeight: CGFloat = 196

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            photo

            HStack(alignment: .center, spacing: VFSpacing.xs) {
                Text(log.matchup)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: VFSpacing.xs)
                VFResultStamp(result: log.result, size: 38)
            }

            VFMetaRow(
                systemImage: "mappin.and.ellipse",
                text: [log.dateText, log.stadium].filter { !$0.isEmpty }.joined(separator: " · ")
            )

            if !log.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(log.diary)
                    .font(VFTypography.body)
                    .foregroundStyle(VFColor.bodySecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, VFSpacing.sm)
        .padding(.top, VFSpacing.sm)
        .padding(.bottom, VFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.photo, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.photo, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .shadow(color: VFShadow.liftedColor, radius: VFShadow.liftedRadius, y: VFShadow.liftedOffsetY)
        .overlay(alignment: .top) {
            VFTapeStrip(width: 64)
                .offset(y: -9)
        }
        .vfTilt(VFTilt.card, reduceMotion: reduceMotion)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var photo: some View {
        ZStack {
            if let ref = log.photoLocalRefs.first {
                AttachmentPhotoView(ref: ref, target: .feedStrip)
            } else {
                // 사진이 없는 기록도 카드가 무너지지 않도록 종이 질감으로 채운다.
                VFColor.subtleSurface
                VFIllustrationView(.ticket, height: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: photoHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.photo - 2, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - 티켓 기록 카드

/// Pencil `기록 카드`. 왼쪽 날짜 반쪽과 오른쪽 본문이 절취선으로 나뉜 티켓 형태.
///
/// Dynamic Type이 접근성 크기로 커지면 가로 티켓 배치로는 글자가 잘리므로
/// 세로 배치로 바꾼다. 정보는 하나도 숨기지 않는다.
struct VFRecordCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let log: AttendanceLogViewState

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedLayout
            } else {
                ticketLayout
            }
        }
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: 1)
        )
        .shadow(color: VFShadow.cardColor, radius: VFShadow.cardRadius, y: VFShadow.cardOffsetY)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: 배치

    private var ticketLayout: some View {
        HStack(spacing: 0) {
            dateStub
                .frame(width: 72)
            perforation
            recordBody
            photoCorner
                .frame(width: 98)
        }
        .frame(minHeight: 120)
    }

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                dateStub
                Spacer(minLength: VFSpacing.xs)
                VFResultStamp(result: log.result, size: 42)
            }
            Rectangle()
                .fill(VFColor.hairline)
                .frame(height: 1)
            recordBody
        }
        .padding(VFSpacing.md)
    }

    // MARK: 조각

    private var dateStub: some View {
        VStack(spacing: 1) {
            Text(monthText)
                .font(Font.system(.caption2, design: .default).weight(.medium))
                .foregroundStyle(VFColor.bodyTertiary)
            Text(dayText)
                .font(VFTypography.numericEmphasis)
                .foregroundStyle(VFColor.bodyPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(weekdayText)
                .font(Font.system(.caption2, design: .default))
                .foregroundStyle(VFColor.bodyTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    /// Pencil 절취선. 점선 한 줄로 티켓을 반으로 가른다.
    private var perforation: some View {
        VFDashedLine()
            .stroke(
                VFColor.hairline,
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 5])
            )
            .frame(width: 1.5)
            .padding(.vertical, VFSpacing.sm)
            .accessibilityHidden(true)
    }

    private var recordBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: VFSpacing.xs) {
                Text(log.matchup)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if log.ourScore != nil, log.opponentScore != nil {
                    Text(log.scoreText)
                        .font(Font.system(.callout, design: .default).weight(.bold).monospacedDigit())
                        .foregroundStyle(scoreTint)
                }
            }

            // Pencil은 구장 줄을 잔디색 세미볼드로 올려 회색 메타데이터에서 벗어나게 한다.
            if !metaText.isEmpty {
                Text(metaText)
                    .font(Font.system(.caption, design: .default).weight(.semibold))
                    .foregroundStyle(VFColor.supportAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !log.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(log.diary)
                    .font(VFTypography.supporting)
                    .foregroundStyle(VFColor.bodySecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(dynamicTypeSize.isAccessibilitySize ? 0 : 14)
    }

    /// Pencil 사진 영역. 최신 문서에서는 기울기와 테이프가 사라지고, 사진 위에
    /// 결과 스탬프만 겹친다. 사진이 없으면 잔디색 판과 이미지 기호를 보여준다.
    private var photoCorner: some View {
        ZStack {
            ZStack {
                if let ref = log.photoLocalRefs.first {
                    AttachmentPhotoView(ref: ref, target: .editorThumbnail)
                } else {
                    VFColor.supportAccentPale
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(VFColor.bodyTertiary)
                }
            }
            .frame(width: 66, height: 80)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VFColor.elevatedSurface, lineWidth: 3)
            )
            .shadow(color: VFShadow.cardColor, radius: 6, y: 2)

            VFResultStamp(result: log.result, size: 40)
                .offset(x: 20, y: 26)
        }
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    /// 스코어 색. 승은 결과색, 그 밖에는 잉크 계열로 눌러 결과를 색으로만 말하지 않는다.
    private var scoreTint: Color {
        switch log.result {
        case .win: VFColor.primaryActionDeep
        case .loss: VFColor.deepAccent
        case .draw, .canceled: VFColor.bodySecondary
        }
    }

    // MARK: 표시 문자열

    private var metaText: String {
        [log.stadium, log.seat, log.companion]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " · ")
    }

    /// 날짜 조각은 미리 계산된 `date`에서 읽는다. View가 날짜를 다시 계산하지 않는다.
    private var monthText: String { DateFormatter.vfRecordStubMonth.string(from: log.date) }
    private var dayText: String { DateFormatter.vfRecordStubDay.string(from: log.date) }
    private var weekdayText: String { DateFormatter.vfRecordStubWeekday.string(from: log.date) }

    private var accessibilityDescription: String {
        [log.dateText, log.matchup, log.resultScoreText, metaText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// 세로 점선 한 줄.
private struct VFDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

extension DateFormatter {
    /// 티켓 날짜 반쪽에 쓰는 조각들. 앱 전체와 같은 ko_KR / Asia/Seoul 기준이다.
    static let vfRecordStubMonth: DateFormatter = vfRecordStub(format: "M월")
    static let vfRecordStubDay: DateFormatter = vfRecordStub(format: "d")
    static let vfRecordStubWeekday: DateFormatter = vfRecordStub(format: "EEEE")

    private static func vfRecordStub(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = format
        return formatter
    }
}

// MARK: - 프리뷰

#Preview("기록 카드") {
    ScrollView {
        VStack(spacing: VFSpacing.sm) {
            ForEach(AttendanceLogSample.logs) { log in
                VFRecordCard(log: log)
            }
        }
        .padding(VFSpacing.md)
    }
    .vfScreenBackground()
}

#Preview("기록 카드 · AccessibilityXXXL") {
    ScrollView {
        VStack(spacing: VFSpacing.sm) {
            ForEach(AttendanceLogSample.logs.prefix(2)) { log in
                VFRecordCard(log: log)
            }
        }
        .padding(VFSpacing.md)
    }
    .vfScreenBackground()
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("폴라로이드 카드") {
    ScrollView {
        VStack(spacing: VFSpacing.xl) {
            ForEach(AttendanceLogSample.logs.prefix(2)) { log in
                VFPolaroidCard(log: log)
            }
        }
        .padding(VFSpacing.md)
    }
    .vfScreenBackground()
}
