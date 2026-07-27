import Photos
import SwiftUI
import UIKit

enum DiaryShareCardStyle: String, CaseIterable, Identifiable {
    case score
    case diary
    case winRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .score: "스코어 카드"
        case .diary: "다이어리 카드"
        case .winRate: "승률 카드"
        }
    }
}

struct ShareCardPreviewView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let log: AttendanceLogViewState?
    var seasonWinRateText: String?
    @State private var selectedStyle: DiaryShareCardStyle = .score
    @State private var renderedImage: UIImage?
    @State private var isShowingShareSheet = false
    @State private var message: String?

    init(log: AttendanceLogViewState? = nil, seasonWinRateText: String? = nil) {
        self.log = log
        self.seasonWinRateText = seasonWinRateText
    }

    var body: some View {
        ScrollView {
            VStack(spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "카드 저장 및 공유", subtitle: "다이어리 기록을 안전한 공유 카드로 만들어요.")

                Picker("카드 스타일", selection: $selectedStyle) {
                    ForEach(DiaryShareCardStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                DiaryShareCardCanvas(log: cardLog, style: selectedStyle, seasonWinRateText: seasonWinRateText)
                    .frame(width: 330, height: 586)
                    .shadow(color: theme.primary.opacity(0.22), radius: 24, y: 12)

                if let message {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VFColor.bodySecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: VFSpacing.sm) {
                    VFSecondaryButton(title: "이미지 저장", systemImage: "square.and.arrow.down") {
                        Task { await saveRenderedCard() }
                    }
                    VFPrimaryButton(title: "공유하기", systemImage: "square.and.arrow.up") {
                        renderedImage = renderCard()
                        isShowingShareSheet = renderedImage != nil
                    }
                }

                VFSecondaryButton(title: "닫기", systemImage: "xmark") {
                    dismiss()
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("공유 카드")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingShareSheet) {
            if let renderedImage {
                ActivityView(items: [renderedImage])
            }
        }
        .vfScreenBackground()
    }

    private var cardLog: AttendanceLogViewState {
        log ?? AttendanceLogSample.logs.first ?? .init(
            id: UUID(),
            date: .now,
            dateText: DateFormatter.vfDisplayDate.string(from: .now),
            matchup: "우리팀 vs 상대팀",
            stadium: "구장 미정",
            result: .win,
            ourScore: nil,
            opponentScore: nil,
            seat: "",
            companion: "",
            memo: "직관 기록을 카드로 남겨보세요.",
            caption: "직관 기록을 카드로 남겨보세요.",
            diary: "직관 기록을 카드로 남겨보세요.",
            tags: [],
            photoLocalRefs: []
        )
    }

    @MainActor
    private func saveRenderedCard() async {
        guard let image = renderCard() else {
            message = "카드를 이미지로 만들지 못했어요."
            return
        }
        renderedImage = image
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let granted: Bool
        switch status {
        case .authorized, .limited:
            granted = true
        case .notDetermined:
            granted = await requestPhotoPermission()
        default:
            granted = false
        }

        guard granted else {
            message = "사진 저장 권한이 없어 저장하지 못했어요. 공유하기는 계속 사용할 수 있어요."
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            message = "이미지를 사진 앱에 저장했어요."
        } catch {
            message = "이미지 저장에 실패했어요. 공유하기를 사용해 주세요."
        }
    }

    @MainActor
    private func requestPhotoPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }

    @MainActor
    private func renderCard() -> UIImage? {
        let renderer = ImageRenderer(
            content: DiaryShareCardCanvas(log: cardLog, style: selectedStyle, seasonWinRateText: seasonWinRateText)
                .frame(width: 1080, height: 1920)
        )
        renderer.scale = 1
        return renderer.uiImage
    }
}

struct DiaryShareCardCanvas: View {
    @Environment(\.appTheme) private var theme
    let log: AttendanceLogViewState
    let style: DiaryShareCardStyle
    var seasonWinRateText: String?
    private let photoService = PhotoAttachmentService()

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text(style.title)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("VictoryFairy")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }

                if style == .diary, let firstImage {
                    Image(uiImage: firstImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text(log.resultScoreText)
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 22)
                                .frame(minHeight: 64)
                                .background(.black.opacity(0.48))
                                .clipShape(Capsule())
                                .padding(24)
                        }
                } else {
                    scoreBlock
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(log.dateText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                    Text(log.matchup)
                        .font(.system(size: 58, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                    Text(log.stadium)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                }

                memoBlock

                Spacer()

                HStack(spacing: 16) {
                    shareMetric("결과", log.result.diaryTitle)
                    shareMetric("응원팀", favoriteTeamText)
                    shareMetric("승률", seasonWinRateText ?? "내 기록")
                }
            }
            .padding(64)
        }
        .clipShape(RoundedRectangle(cornerRadius: 54, style: .continuous))
    }

    private var background: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [VFColor.deepAccent, theme.secondary.opacity(0.92), VFColor.primaryAction.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(.white.opacity(0.055))
                    .frame(height: 3)
                    .rotationEffect(.degrees(-12))
                    .offset(y: CGFloat(index * 120) - 160)
            }
            Text(style == .winRate ? "%" : log.result.title)
                .font(.system(size: 420, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 56, y: 80)
        }
    }

    private var scoreBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(style == .winRate ? "MY WIN RATE" : "SCORE")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text(style == .winRate ? (seasonWinRateText ?? "내 직관 데이터") : log.resultScoreText)
                .font(.system(size: 88, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.54)
        }
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
    }

    private var memoBlock: some View {
        Text(cardMemo)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(5)
            .minimumScaleFactor(0.72)
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func shareMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(VFColor.bodySecondary)
            Text(value)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(VFColor.bodyPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var firstImage: UIImage? {
        log.photoLocalRefs.first.flatMap { photoService.image(for: $0, target: .shareCard) }
    }

    private var cardMemo: String {
        switch style {
        case .score:
            return log.memo.nilIfBlank ?? log.caption.nilIfBlank ?? "오늘의 직관 기록"
        case .diary:
            return log.diary.nilIfBlank ?? log.memo.nilIfBlank ?? "오늘의 직관 기록"
        case .winRate:
            return "내 직관 데이터 기준으로 남기는 \(log.dateText) 기록"
        }
    }

    private var favoriteTeamText: String {
        KBOSeed.teams.first { team in
            log.matchup.contains(team.name) || log.matchup.contains(team.shortName)
        }?.shortName ?? "우리팀"
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview("공유 카드 미리보기") {
    NavigationStack {
        ShareCardPreviewView(log: AttendanceLogSample.logs.first, seasonWinRateText: "63%")
    }
}
