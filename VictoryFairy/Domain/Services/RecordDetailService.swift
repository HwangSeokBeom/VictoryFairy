import Foundation

/// 저장된 직관 기록 하나를 상세 화면이 그릴 의미 모델로 옮긴다.
///
/// 순수 계산이라 SwiftUI와 SwiftData에 의존하지 않는다. 매치업 해석, 구장 확인, 결과
/// 표기, 점수 형식, 날짜 정책이 모두 여기에 있고 화면에는 없다.
struct RecordDetailService {

    /// 상세 화면이 쓰는 기준 달력. 기기 시간대 설정에 흔들리면 같은 기록이 기기마다
    /// 다른 날짜로 보인다.
    static func referenceCalendar() -> Calendar {
        CalendarMonth.referenceCalendar()
    }

    /// 저장소 매퍼가 값이 없을 때 채워 넣는 표시용 문구.
    ///
    /// `AttendanceLogMapper`는 비어 있는 좌석·동행·메모를 "좌석 미정" 같은 문구로 바꾼다.
    /// 상세 화면이 그 문구를 사용자가 쓴 값처럼 보여 주면 없는 사실을 있는 것처럼 말하게
    /// 된다. 그래서 여기서 다시 "없음"으로 되돌린다.
    static let placeholderValues: Set<String> = ["좌석 미정", "미입력", "직관 기록"]

    /// 미디어 상태는 파일 시스템을 봐야 알 수 있으므로 밖에서 확인해 넘긴다.
    /// 이 타입은 파일을 읽지 않는다.
    func presentation(
        log: AttendanceLogViewState,
        favoriteTeam: KBOTeam?,
        displayName: String?,
        media: RecordDetailMedia,
        calendar: Calendar = RecordDetailService.referenceCalendar()
    ) -> RecordDetailPresentation {
        let stadium = resolveStadium(log: log, favoriteTeam: favoriteTeam)
        return RecordDetailPresentation(
            recordID: log.id,
            navigationTitle: DateFormatter.vfRecordDetailTitle.string(from: log.date),
            title: real(log.memo),
            placeMeta: placeMeta(log: log, stadium: stadium),
            matchup: resolveMatchup(log: log, favoriteTeam: favoriteTeam),
            stadium: stadium,
            media: media,
            note: resolveNote(log: log, stadium: stadium, displayName: displayName),
            moodTag: real(log.tags.first),
            highlightTags: Array(log.tags.dropFirst()).compactMap { real($0) },
            details: resolveDetails(log: log),
            officialRecordURL: log.officialRecordURL.flatMap(URL.init(string:)),
            sourceLabel: log.subtleSourceLabel,
            season: calendar.component(.year, from: log.date)
        )
    }

    /// VoiceOver가 읽을 날짜. 숫자만 읽지 않고 요일까지 온전히 읽는다.
    func spokenDate(for log: AttendanceLogViewState) -> String {
        DateFormatter.vfRecordDetailVoiceOver.string(from: log.date)
    }

    // MARK: - 조각들

    /// 저장소가 채워 넣은 표시용 문구는 사용자가 쓴 값이 아니다.
    private func real(_ value: String?) -> String? {
        guard let trimmed = value?.trimmedOrNil,
              !Self.placeholderValues.contains(trimmed) else { return nil }
        return trimmed
    }

    /// Pencil `장소 메타`. Pencil은 경기 시작 시각까지 적지만 이 앱에는 시각 데이터원이
    /// 없으므로 실제로 저장된 구장과 좌석만 잇는다.
    private func placeMeta(log: AttendanceLogViewState, stadium: RecordDetailStadium) -> String? {
        let parts = [stadium.name, real(log.seat)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 기록에 적힌 두 팀을 canonical 등록부로 옮긴다.
    /// 응원 팀을 찾지 못하면 적힌 순서를 그대로 쓴다.
    private func resolveMatchup(
        log: AttendanceLogViewState,
        favoriteTeam: KBOTeam?
    ) -> RecordDetailMatchup {
        let matchup = log.resolvedMatchup
        let sides = matchup.sides(favoriteTeamID: favoriteTeam?.id)
        let mineIsSecond = sides.mine?.id != nil && sides.mine?.id == matchup.secondTeam?.id
        return RecordDetailMatchup(
            myTeam: RecordDetailTeam(
                team: sides.mine,
                fallbackLabel: mineIsSecond ? matchup.secondLabel : matchup.firstLabel
            ),
            opponent: RecordDetailTeam(
                team: sides.opponent,
                fallbackLabel: mineIsSecond ? matchup.firstLabel : matchup.secondLabel
            ),
            result: log.result,
            myScore: log.result == .canceled ? nil : log.ourScore,
            opponentScore: log.result == .canceled ? nil : log.opponentScore
        )
    }

    /// 기록에 남은 구장을 그대로 쓴다. 주 관람 구장이나 팀 홈 구장으로 대체하지 않는다.
    private func resolveStadium(
        log: AttendanceLogViewState,
        favoriteTeam: KBOTeam?
    ) -> RecordDetailStadium {
        let recordedName = log.stadium.trimmedOrNil
        guard let recordedName else {
            return RecordDetailStadium(stadiumID: nil, name: nil, isHomeGame: nil, meta: nil)
        }
        guard let known = KBOStadiumSeed.all.first(where: { $0.name == recordedName }) else {
            // 등록부에 없는 이름이어도 기록에 적힌 대로 보여 준다. 다른 구장으로 바꾸지 않는다.
            return RecordDetailStadium(
                stadiumID: nil, name: recordedName, isHomeGame: nil, meta: nil
            )
        }
        let homeTeamNames = known.homeTeamIDs.compactMap { KBOSeed.team(id: $0)?.name }
        let meta = ([known.city] + homeTeamNames.map { "\($0) 홈" })
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return RecordDetailStadium(
            stadiumID: known.id,
            name: known.name,
            // 응원 팀을 모르면 홈·원정을 단정하지 않는다.
            isHomeGame: favoriteTeam.map { known.homeTeamIDs.contains($0.id) },
            meta: meta.isEmpty ? nil : meta
        )
    }

    /// Pencil `일기 섹션`. 사용자가 쓴 글만 담고 문장을 만들어 주지 않는다.
    private func resolveNote(
        log: AttendanceLogViewState,
        stadium: RecordDetailStadium,
        displayName: String?
    ) -> RecordDetailNote {
        let body = log.diary.trimmedOrNil
        // Pencil `일기 서명`은 "— 잠실에서, 민지" 형태다. 구장과 이름이 모두 있고
        // 본문이 있을 때만 만든다. 이름을 지어내지 않는다.
        let signature: String? = {
            guard body != nil,
                  let stadiumName = stadium.name,
                  let name = displayName?.trimmedOrNil else { return nil }
            return "— \(stadiumName)에서, \(name)"
        }()
        return RecordDetailNote(body: body, signature: signature)
    }

    /// Pencil `그날의 작은 것들`. Pencil은 날씨·먹은 것·응원 준비물까지 그리지만
    /// 도메인에 그 세 항목이 없다. 지어내지 않고 실제로 저장되는 두 가지만 남긴다.
    private func resolveDetails(log: AttendanceLogViewState) -> [RecordDetailFact] {
        var facts: [RecordDetailFact] = []
        if let companion = real(log.companion) {
            facts.append(RecordDetailFact(kind: .companion, label: "함께한 사람", value: companion))
        }
        if let seat = real(log.seat) {
            facts.append(RecordDetailFact(kind: .seat, label: "좌석", value: seat))
        }
        return facts
    }
}
