import SwiftUI

/// Pencil `08_RecordDetail` 한 장이 필요로 하는 값.
///
/// 계산은 모두 `RecordDetailService`가 한다. 이 타입은 뷰가 아니므로 화면 밖에서 그대로
/// 만들 수 있고, 화면은 여기 담긴 의미 모델을 그리기만 한다.
struct RecordDetailViewModel {
    let log: AttendanceLogViewState
    let presentation: RecordDetailPresentation
    let dataState: RecordDetailDataState
    let spokenDate: String

    init(
        log: AttendanceLogViewState,
        favoriteTeam: KBOTeam?,
        displayName: String?,
        media: RecordDetailMedia,
        dataState: RecordDetailDataState = .loaded
    ) {
        let service = RecordDetailService()
        self.log = log
        self.dataState = dataState
        presentation = service.presentation(
            log: log,
            favoriteTeam: favoriteTeam,
            displayName: displayName,
            media: media
        )
        spokenDate = service.spokenDate(for: log)
    }
}

/// Pencil `08_RecordDetail`.
///
/// 하나의 직관 기록을 편집자적으로 보여 준다. 스크랩북이나 카드 더미가 아니라,
/// 언제·누구와·어떤 결과였고·어디였고·무엇을 남겼는지가 순서대로 읽히는 화면이다.
struct AttendancePostDetailView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore

    let log: AttendanceLogViewState

    @State private var isShowingEditor = false
    @State private var isShowingDeleteConfirmation = false
    @State private var safariRoute: SafariRoute?
    @State private var deletionError: String?
    @State private var isDeleting = false

    private var viewModel: RecordDetailViewModel {
        RecordDetailViewModel(
            log: VFUITestConfiguration.recordDetailLog(log),
            favoriteTeam: appData.team(id: preferences.favoriteTeamID),
            displayName: preferences.userDisplayName,
            media: VFUITestConfiguration.recordDetailMedia(
                PhotoAttachmentService().mediaState(
                    for: VFUITestConfiguration.recordDetailLog(log).photoLocalRefs,
                    maxPixel: PhotoDisplayTarget.detailStrip.maxPixel
                )
            ),
            dataState: VFUITestConfiguration.recordDetailState(.loaded)
        )
    }

    private var detail: RecordDetailPresentation { viewModel.presentation }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                switch viewModel.dataState {
                case .loading:
                    VFLoadingPanel(message: "기록을 불러오는 중이에요")
                        .accessibilityIdentifier(RecordDetailAccessibilityID.loading)
                case .error(let message):
                    VFErrorPanel(
                        message: message,
                        retryAccessibilityIdentifier: RecordDetailAccessibilityID.retry
                    ) {
                        Task { await appData.refreshContent() }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(RecordDetailAccessibilityID.error)
                case .loaded:
                    loadedContent
                }

                fixtureScenarioMarker
            }
            .padding(VFSpacing.md)
            .vfTabContentPadding()
        }
        .accessibilityIdentifier(RecordDetailAccessibilityID.root)
        .navigationTitle(detail.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { overflowMenu }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                // 기존 편집 경로를 그대로 쓴다. 두 번째 편집기를 만들지 않는다.
                LogEditorView(editingLog: viewModel.log)
            }
        }
        .sheet(item: $safariRoute) { route in
            SafariView(url: route.url)
        }
        // Pencil `09_States`의 `삭제 다이얼로그`는 화면 가운데 뜨는 카드에 제목·본문과
        // 취소·삭제 두 버튼이 나란히 놓인 형태다. 그래서 액션 시트가 아니라 얼럿을 쓴다.
        //
        // 액션 시트(`confirmationDialog`)로 만들었을 때는 취소 버튼이 접근성 트리에
        // **이름 없는 버튼**으로 나왔다. 화면을 읽는 사람에게는 무엇을 누르는지 알 수 없는
        // 칸이 되므로 그대로 둘 수 없었다. 얼럿은 두 버튼의 이름을 모두 그대로 노출한다.
        .alert("이 기록을 삭제할까요?", isPresented: $isShowingDeleteConfirmation) {
            Button("남겨둘래요", role: .cancel) {}
                .accessibilityIdentifier(RecordDetailAccessibilityID.deleteCancel)
            Button("삭제하기", role: .destructive) {
                Task { await performDeletion() }
            }
            .accessibilityIdentifier(RecordDetailAccessibilityID.deleteConfirm)
        } message: {
            Text("삭제한 기억은 되돌릴 수 없어요.\n사진은 보관함에 그대로 남아요.")
        }
        .vfScreenBackground()
    }

    // MARK: - 본문

    @ViewBuilder
    private var loadedContent: some View {
        RecordDetailMediaView(media: detail.media, result: detail.matchup.result)

        titleBlock

        RecordDetailScoreboard(matchup: detail.matchup)

        RecordDetailStadiumView(stadium: detail.stadium)

        noteSection

        if !detail.highlightTags.isEmpty {
            highlightSection
        }

        if !detail.details.isEmpty {
            detailsSection
        }

        if let mood = detail.moodTag {
            moodRow(mood)
        }

        if let deletionError {
            deletionFailureNotice(deletionError)
        }

        actions

        officialRecordLink
    }

    /// Pencil `제목 블록`. 사용자가 남긴 한 줄 메모가 제목이 된다.
    @ViewBuilder
    private var titleBlock: some View {
        if detail.title != nil || detail.placeMeta != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let title = detail.title {
                    Text(title)
                        .font(VFTypography.display)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(RecordDetailAccessibilityID.title)
                }
                if let placeMeta = detail.placeMeta {
                    Text(placeMeta)
                        .font(VFTypography.supporting)
                        .foregroundStyle(VFColor.bodyTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(RecordDetailAccessibilityID.placeMeta)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }

    /// Pencil `일기 섹션`. 사용자가 쓴 글만 그대로 보여 준다.
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "이날의 일기")

            if let body = detail.note.body {
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text(body)
                        .font(Font.system(.subheadline, design: .default))
                        .foregroundStyle(VFColor.bodyPrimary)
                        .lineSpacing(7)
                        // 고정 높이를 두지 않는다. 긴 글도 잘리지 않고 세로로 자란다.
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    if let signature = detail.note.signature {
                        Text(signature)
                            .font(VFTypography.metadata)
                            .foregroundStyle(VFColor.bodyTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(VFSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VFColor.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                        .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(RecordDetailAccessibilityID.note)
            } else {
                Text(detail.note.emptyMessage)
                    .font(VFTypography.supporting)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(VFSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VFColor.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                            .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
                    )
                    .accessibilityIdentifier(RecordDetailAccessibilityID.noteEmpty)
            }
        }
    }

    /// Pencil `순간 섹션`. Pencil은 "9회초 박병호, 역전 스리런" 같은 문장을 적지만
    /// 이 앱에는 선수·이닝 데이터원이 없다. 실제로 저장되는 하이라이트 태그만 보여 준다.
    private var highlightSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "가장 기억에 남는 순간")

            ForEach(detail.highlightTags, id: \.self) { tag in
                HStack(spacing: VFSpacing.xs) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: VFIconSize.small, weight: .semibold))
                        .foregroundStyle(VFColor.primaryActionDeep)
                        .accessibilityHidden(true)
                    Text(tag)
                        .font(Font.system(.subheadline, design: .default).weight(.medium))
                        .foregroundStyle(VFColor.bodyPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, VFSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
                .background(VFColor.highlightSurface)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RecordDetailAccessibilityID.highlights)
    }

    /// Pencil `디테일 섹션`. 도메인이 실제로 들고 있는 항목만 남는다.
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "그날의 작은 것들")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: VFSpacing.xs) { detailCells }
                VStack(spacing: VFSpacing.xs) { detailCells }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RecordDetailAccessibilityID.details)
    }

    @ViewBuilder
    private var detailCells: some View {
        ForEach(detail.details) { fact in
            HStack(spacing: VFSpacing.sm) {
                Image(systemName: fact.kind == .companion ? "person.2.fill" : "chair.fill")
                    .font(.system(size: VFIconSize.medium, weight: .medium))
                    .foregroundStyle(VFColor.bodySecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label)
                        .font(Font.system(.caption2, design: .default))
                        .foregroundStyle(VFColor.bodyTertiary)
                    Text(fact.value)
                        .font(Font.system(.subheadline, design: .default).weight(.semibold))
                        .foregroundStyle(VFColor.bodyPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, VFSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
            .background(VFColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous)
                    .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(fact.accessibilityLabel)
            .accessibilityIdentifier(fact.accessibilityIdentifier)
        }
    }

    /// Pencil `무드 섹션`. 별점은 도메인에 없으므로 두지 않는다.
    private func moodRow(_ mood: String) -> some View {
        HStack(spacing: VFSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("이날의 기분")
                    .font(Font.system(.caption2, design: .default))
                    .foregroundStyle(VFColor.bodySecondary)
                Text(mood)
                    .font(Font.system(.callout, design: .default).weight(.heavy))
                    .foregroundStyle(VFColor.primaryActionDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VFSpacing.md)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.primaryActionPale)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("이날의 기분, \(mood)")
        .accessibilityIdentifier(RecordDetailAccessibilityID.mood)
    }

    /// Pencil `상세 액션`. 공유가 먼저, 수정이 그다음이다.
    private var actions: some View {
        VStack(spacing: VFSpacing.xs) {
            NavigationLink {
                ShareCardPreviewView(log: viewModel.log)
            } label: {
                HStack(spacing: VFSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                    Text("추억 카드로 공유하기")
                }
                .font(Font.system(.callout, design: .default).weight(.bold))
                .foregroundStyle(VFColor.bodyPrimary)
                .frame(maxWidth: .infinity, minHeight: VFControl.buttonHeight)
                .background(VFColor.primaryAction)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous)
                        .stroke(VFColor.inkOutline, lineWidth: VFStroke.ink)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(RecordDetailAccessibilityID.share)

            VFSecondaryButton(title: "기록 수정하기", systemImage: "square.and.pencil") {
                isShowingEditor = true
            }
            .accessibilityIdentifier(RecordDetailAccessibilityID.edit)
        }
    }

    /// 서버가 공식 기록 링크를 준 경우에만 나온다.
    @ViewBuilder
    private var officialRecordLink: some View {
        if let url = detail.officialRecordURL {
            Button {
                safariRoute = SafariRoute(url: url)
            } label: {
                HStack(spacing: VFSpacing.xs) {
                    Image(systemName: "safari")
                    Text("공식 기록 보기")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
                .background(VFColor.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                        .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(RecordDetailAccessibilityID.officialRecord)
        }
    }

    /// 삭제에 실패하면 화면을 떠나지 않고 그 사실을 알린다.
    private func deletionFailureNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: VFSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: VFIconSize.small, weight: .semibold))
                .foregroundStyle(VFColor.statusError)
                .accessibilityHidden(true)
            Text(message)
                .font(VFTypography.metadata)
                .foregroundStyle(VFColor.bodyPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VFSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.statusError.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityIdentifier(RecordDetailAccessibilityID.error)
    }

    /// Pencil 내비바의 오른쪽 액션.
    ///
    /// Pencil은 이 자리에 공유 아이콘을 두지만, 바로 아래에 "추억 카드로 공유하기"
    /// 버튼이 이미 있어 같은 동작이 두 번 나온다. 대신 컴포넌트의 기본값인 더보기
    /// 메뉴로 두고, Pencil 프레임에 자리가 없는 삭제를 여기에 담는다.
    @ToolbarContentBuilder
    private var overflowMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    isShowingEditor = true
                } label: {
                    Label("기록 수정하기", systemImage: "square.and.pencil")
                }
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("기록 삭제하기", systemImage: "trash")
                }
                .accessibilityIdentifier(RecordDetailAccessibilityID.delete)
            } label: {
                Image(systemName: "ellipsis")
                    .accessibilityLabel("기록 관리")
            }
            .disabled(isDeleting)
            .accessibilityIdentifier(RecordDetailAccessibilityID.overflow)
        }
    }

    /// 삭제는 화면이 아니라 저장소 소유자가 수행한다. 여기서는 결과만 받아 처리한다.
    private func performDeletion() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        deletionError = nil

        let log = viewModel.log
        let outcome = await VFUITestConfiguration.recordDetailDeletion {
            await appData.deleteAttendanceLog(log)
        }

        switch outcome {
        case .deleted:
            dismiss()
        case .failed(let message):
            // 실패했으면 화면을 떠나지 않는다. 기록도 그대로 남아 있다.
            deletionError = message
        }
    }

    /// UI 테스트가 픽스처 적용 여부를 화면에서 확인하기 위한 표식.
    @ViewBuilder
    private var fixtureScenarioMarker: some View {
        if let identifier = VFUITestConfiguration.activeRecordDetailScenarioIdentifier {
            // 조회할 수 있는 요소여야 한다. `accessibilityHidden`을 붙이면 접근성 트리에서
            // 통째로 빠져 UI 테스트가 영영 찾지 못한다. 대신 읽을 이름을 비워 둔다.
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(Text(verbatim: ""))
        }
    }
}

// MARK: - 사진 영역

/// Pencil `히어로 사진`. 사진 한 장 위에 결과 스탬프가 얹힌다.
///
/// 사진이 없는 것과 파일이 사라진 것과 열 수 없는 것을 각각 다르게 말한다.
/// 셋을 같은 회색 사각형으로 뭉개면 무엇이 잘못됐는지 알 수 없다.
struct RecordDetailMediaView: View {
    let media: RecordDetailMedia
    let result: GameResult

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .frame(maxWidth: .infinity)
                .frame(height: 234)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                        .stroke(VFColor.elevatedSurface, lineWidth: 4)
                )
                .shadow(color: VFShadow.liftedColor, radius: VFShadow.liftedRadius, y: VFShadow.liftedOffsetY)

            VFResultStamp(result: result)
                .padding(VFSpacing.sm)
                .accessibilityIdentifier(RecordDetailAccessibilityID.result)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RecordDetailAccessibilityID.media)
    }

    @ViewBuilder
    private var content: some View {
        switch media {
        case .available(let refs):
            if let ref = refs.first {
                AttachmentPhotoView(ref: ref, target: .detailStrip)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("이 기록의 사진")
                    .accessibilityIdentifier(
                        RecordDetailAccessibilityID.media(media.accessibilityIdentifierSuffix)
                    )
            } else {
                placeholder(systemImage: "photo", message: media.message)
            }
        case .loading:
            placeholder(systemImage: "clock", message: media.message)
        case .none:
            placeholder(systemImage: "photo.on.rectangle", message: media.message)
        case .missingFile:
            placeholder(systemImage: "questionmark.folder", message: media.message)
        case .decodeFailed:
            placeholder(systemImage: "exclamationmark.triangle", message: media.message)
        }
    }

    /// 사진이 없을 때도 같은 자리를 차지해 레이아웃이 흔들리지 않게 한다.
    private func placeholder(systemImage: String, message: String?) -> some View {
        ZStack {
            VFColor.subtleSurface
            VStack(spacing: VFSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(VFColor.bodyTertiary)
                if let message {
                    Text(message)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(VFSpacing.md)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message ?? media.spokenSummary)
        .accessibilityIdentifier(
            RecordDetailAccessibilityID.media(media.accessibilityIdentifierSuffix)
        )
    }
}

// MARK: - 스코어보드

/// Pencil `스코어보드`. 남색 카드 위에 두 팀과 최종 점수.
///
/// Pencil은 이닝별 라인스코어까지 그리지만 이 앱에는 이닝 데이터원이 없다.
/// 숫자를 지어내지 않고 실제로 저장된 최종 점수만 보여 준다.
struct RecordDetailScoreboard: View {
    let matchup: RecordDetailMatchup

    var body: some View {
        VStack(spacing: VFSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: VFSpacing.sm) {
                    teamColumn(matchup.myTeam, identifier: myTeamIdentifier, isMine: true)
                    scoreView
                    teamColumn(matchup.opponent, identifier: opponentIdentifier, isMine: false)
                }
                VStack(spacing: VFSpacing.sm) {
                    teamColumn(matchup.myTeam, identifier: myTeamIdentifier, isMine: true)
                    scoreView
                    teamColumn(matchup.opponent, identifier: opponentIdentifier, isMine: false)
                }
            }

            // 색만으로 결과를 전하지 않는다. 결과는 언제나 글자로도 남는다.
            Text(matchup.resultDescription)
                .font(Font.system(.footnote, design: .default).weight(.bold))
                .foregroundStyle(VFColor.bodyOnDark)
                .padding(.horizontal, VFSpacing.sm)
                .padding(.vertical, 4)
                .background(VFColor.bodyOnDark.opacity(0.14))
                .clipShape(Capsule())
        }
        .padding(VFSpacing.md)
        .frame(maxWidth: .infinity)
        .background(VFColor.deepAccent)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous)
                .stroke(VFColor.inkOutline, lineWidth: 1.4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RecordDetailAccessibilityID.scoreboard)
    }

    private var myTeamIdentifier: String {
        RecordDetailAccessibilityID.team(matchup.myTeam?.accessibilityIdentifierSuffix ?? "missing")
    }

    private var opponentIdentifier: String {
        RecordDetailAccessibilityID.opponent(matchup.opponent?.accessibilityIdentifierSuffix ?? "missing")
    }

    @ViewBuilder
    private func teamColumn(_ team: RecordDetailTeam?, identifier: String, isMine: Bool) -> some View {
        HStack(spacing: VFSpacing.xs) {
            Circle()
                .fill(VFColor.elevatedSurface)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(team?.badgeText ?? "?")
                        .font(Font.system(size: 11, weight: .bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .foregroundStyle(VFColor.deepAccent)
                )
                .accessibilityHidden(true)
            Text(team?.name ?? "상대 미기록")
                .font(Font.system(.footnote, design: .default).weight(isMine ? .bold : .semibold))
                .foregroundStyle(team == nil ? VFColor.bodyOnDarkSecondary : VFColor.bodyOnDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            team.map { isMine ? "나의 팀 \($0.name)" : "상대 팀 \($0.name)" } ?? "상대 팀 미기록"
        )
        .accessibilityIdentifier(identifier)
    }

    /// 점수가 없으면 숫자를 만들지 않고 왜 없는지 말한다.
    @ViewBuilder
    private var scoreView: some View {
        if let scoreText = matchup.scoreText {
            Text(scoreText)
                .font(Font.system(.largeTitle, design: .default).weight(.bold).monospacedDigit())
                .foregroundStyle(VFColor.attentionAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier(RecordDetailAccessibilityID.score)
                .accessibilityLabel(matchup.spokenSummary)
        } else if let placeholder = matchup.scorePlaceholder {
            Text(placeholder)
                .font(Font.system(.subheadline, design: .default).weight(.bold))
                .foregroundStyle(VFColor.bodyOnDarkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(RecordDetailAccessibilityID.score)
        }
    }
}

// MARK: - 구장

/// Pencil `구장 히어로`. 기록에 남은 구장을 그대로 보여 준다.
struct RecordDetailStadiumView: View {
    let stadium: RecordDetailStadium

    var body: some View {
        Group {
            if let known = stadium.stadiumID.flatMap(KBOStadiumSeed.stadium(id:)) {
                VFStadiumHero(stadium: known, caption: caption)
            } else {
                unknownVenue
            }
        }
        .accessibilityIdentifier(
            RecordDetailAccessibilityID.stadium(stadium.accessibilityIdentifierSuffix)
        )
    }

    /// Pencil `구장 히어로`는 아이브로우와 메타를 **두 줄**로 나눈다.
    /// 한 줄로 이으면 잠실처럼 홈 팀이 둘인 구장에서 좁은 폭을 넘긴다.
    private var caption: String? {
        [stadium.eyebrow, stadium.meta].compactMap { $0 }.joined(separator: "\n").trimmedOrNil
    }

    /// 등록부에 없거나 적히지 않은 구장. 다른 구장으로 바꾸지 않고 사실만 말한다.
    private var unknownVenue: some View {
        HStack(spacing: VFSpacing.sm) {
            Image(systemName: "mappin.slash")
                .font(.system(size: VFIconSize.medium, weight: .medium))
                .foregroundStyle(VFColor.bodyTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(stadium.name == nil ? "구장 정보 없음" : "등록되지 않은 구장")
                    .font(Font.system(.caption2, design: .default))
                    .foregroundStyle(VFColor.bodyTertiary)
                Text(stadium.name ?? "이 기록에는 구장이 적혀 있지 않아요")
                    .font(Font.system(.subheadline, design: .default).weight(.semibold))
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, VFSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous)
                .stroke(VFColor.hairline, lineWidth: VFStroke.hairline)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stadium.spokenSummary)
    }
}

#Preview("기록 상세") {
    let preferences = UserPreferencesStore.preview(suiteName: "RecordDetailPreview")
    return NavigationStack {
        if let log = AttendanceLogSample.logs.first {
            AttendancePostDetailView(log: log)
        } else {
            Text("No sample log")
        }
    }
    .environmentObject(preferences)
    .environmentObject(AppDataStore(preferences: preferences))
}
