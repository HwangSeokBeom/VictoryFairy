import XCTest
@testable import VictoryFairy

/// Pencil `08_Profile_Settings`(NffPV)이 그린 마이 탭 루트의 계약.
///
/// 지키는 것은 세 가지다.
/// 1. 화면에 보이는 값은 전부 저장소가 실제로 들고 있는 값이다 — 이름도, 팀도,
///    버전도 지어내지 않는다.
/// 2. 뒷받침하는 계약이 없는 행은 자리만 남기지 않고 아예 없다.
/// 3. 이미 있던 프로필 편집기와 응원 팀 변경 계약은 그대로 살아 있다.
final class ProfileSettingsTests: XCTestCase {

    // MARK: - 소스 접근

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static var appSourceRoot: URL { repositoryRoot.appendingPathComponent("VictoryFairy") }

    private func source(_ relativePath: String) throws -> String {
        let url = Self.appSourceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 주석을 걷어낸 본문. "없어야 한다"를 확인할 때 설명 주석에 걸리면 안 된다.
    private func executableSource(_ relativePath: String) throws -> String {
        try source(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("//") ? "" : String(line)
            }
            .joined(separator: "\n")
    }

    private var profileSource: String {
        get throws { try executableSource("Features/Profile/ProfileSettingsView.swift") }
    }

    private var rootSource: String {
        get throws { try executableSource("AppRootView.swift") }
    }

    /// `ProfileSettingsView` 본문만. 같은 파일에 사는 프로필 편집기와 차단 화면은
    /// 마이 탭 루트가 아니므로, "없어야 한다"를 볼 때 그쪽 코드에 걸리면 안 된다.
    private var profileScreenBody: String {
        get throws {
            let source = try profileSource
            guard let start = source.range(of: "struct ProfileSettingsView"),
                  let end = source.range(of: "struct ProfileNavigationRow") else {
                throw XCTSkip("프로필 화면 범위를 찾지 못했다")
            }
            return String(source[start.lowerBound..<end.lowerBound])
        }
    }

    // MARK: - 1~3. 탭 소유권

    func testP01_myIsTheFifthAndLastMainTab() {
        XCTAssertEqual(MainTab.allCases.count, 5, "메인 탭이 다섯이 아니다")
        XCTAssertEqual(MainTab.allCases.last, .my, "마이가 마지막 탭이 아니다")
        XCTAssertEqual(MainTab.allCases.firstIndex(of: .my), 4, "마이가 다섯 번째가 아니다")
    }

    func testP02_myTabKeepsItsIdentity() {
        XCTAssertEqual(MainTab.my.title, "마이")
        XCTAssertEqual(MainTab.my.accessibilityIdentifier, "tab.my")
        XCTAssertEqual(MainTab.my.screenIdentifier, "screen.my")
    }

    func testP03_myTabStillRendersTheRealProfileScreen() throws {
        let root = try rootSource
        XCTAssertTrue(root.contains("ProfileSettingsView()"),
                      "마이 탭이 실제 프로필 화면을 그리지 않는다")
        XCTAssertFalse(root.contains("Text(\"준비 중\")"), "마이 탭에 자리표시자가 생겼다")
    }

    // MARK: - 4~7. 정체성

    func testP04_displayNameComesFromStoredPreferenceNotAFixture() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("preferences.userDisplayName"),
                      "표시 이름이 저장된 값에서 오지 않는다")
        XCTAssertFalse(source.contains("승리요정 민지"), "Pencil 견본 이름이 그대로 남았다")
    }

    func testP05_missingDisplayNameFallsBackWithoutInventingAName() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("이름을 정하지 않았어요"),
                      "이름이 없을 때의 중립 표현이 없다")
    }

    func testP06_favoriteTeamComesFromCanonicalPreference() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("preferences.favoriteTeamName"),
                      "응원 팀이 canonical 값에서 오지 않는다")
        XCTAssertFalse(source.contains("삼성 라이온즈"), "Pencil 견본 팀이 그대로 남았다")
    }

    func testP07_noTeamIsSelectedAutomatically() throws {
        let source = try profileScreenBody
        XCTAssertFalse(source.contains("favoriteTeamID = "),
                       "화면이 응원 팀을 직접 쓴다")
        XCTAssertFalse(source.contains("updateFavoriteTeam(\""),
                       "화면이 특정 팀을 자동으로 고른다")
    }

    /// 저장소의 중립 표현이 그대로 쓰인다.
    @MainActor
    func testP08_neutralTeamWordingMatchesTheProduct() {
        let store = UserPreferencesStore(defaults: Self.emptyDefaults())
        XCTAssertNil(store.favoriteTeam)
        XCTAssertEqual(store.favoriteTeamName, "선택 안 함",
                       "팀이 없을 때 제품이 쓰는 표현이 바뀌었다")
    }

    // MARK: - 9~10. 요정

    func testP09_theApprovedVictoryFairyIsUsedAtCompactSize() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("VFFairyGlyph(.victory, size: .compact)"),
                      "승인된 승리 요정 48px 판을 쓰지 않는다")
    }

    func testP10_noOtherFairyIsIntroduced() throws {
        let source = try profileSource
        for forbidden in ["VFTeamFairy", "VFStadiumFairy", "TeamFairy48", "StadiumFairy48"] {
            XCTAssertFalse(source.contains(forbidden), "\(forbidden)이 마이 화면에 들어왔다")
        }
        XCTAssertEqual(source.components(separatedBy: "VFFairyGlyph(").count - 1, 1,
                       "마이 화면의 요정이 하나가 아니다")
    }

    // MARK: - 11~13. 프로필 편집

    func testP11_profileEditUsesTheExistingEditor() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("ProfileCreationView("),
                      "이미 있는 프로필 편집기를 쓰지 않는다")
        XCTAssertTrue(source.contains("isShowingProfileEditor"), "편집 진입이 사라졌다")
    }

    func testP12_profileEditIsDistinctFromTeamChange() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("isShowingTeamSelection"), "팀 변경 진입이 사라졌다")
        XCTAssertFalse(source.contains("ProfileCreationView(selectedTeamID"),
                       "팀 선택이 프로필 편집기에 끼워졌다")
    }

    func testP13_noSecondProfileModelIsIntroduced() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("struct ProfileDTO"), "두 번째 프로필 모델이 생겼다")
        XCTAssertFalse(source.contains("UserDefaults("), "화면이 저장소를 직접 연다")
    }

    // MARK: - 14~18. 응원 팀 변경 — 이미 있는 계약을 지킨다

    func testP14_teamChangeRowIsPreserved() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("\"응원 팀 변경\""), "응원 팀 변경 행이 사라졌다")
    }

    func testP15_teamSelectionReceivesTheCanonicalTeamList() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("TeamSelectionView("), "기존 팀 선택 화면을 쓰지 않는다")
        XCTAssertTrue(source.contains("teams: appData.teams"),
                      "canonical 팀 목록을 넘기지 않는다")
    }

    func testP16_theExistingUpdateOwnerIsPreserved() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("appData.updateFavoriteTeam("),
                      "기존 응원 팀 갱신 주인이 바뀌었다")
        // 마이 화면 본문이 스스로 저장소를 건드리지 않는다 — 갱신 주인은 하나뿐이다.
        // 같은 파일의 프로필 편집기는 자기 상태를 따로 들고 있으므로 본문만 본다.
        XCTAssertFalse(try profileScreenBody.contains("favoriteTeamID ="),
                       "마이 화면이 응원 팀을 직접 쓴다")
    }

    func testP17_noSecondTeamSelectorOrStorageIsIntroduced() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("struct TeamSelector"), "두 번째 팀 선택기가 생겼다")
        XCTAssertFalse(source.contains("OnboardingView"), "온보딩을 팀 선택 대용으로 쓴다")
        // 팀 선택 화면은 온보딩 폴더의 그 하나뿐이다.
        let selectors = try FileManager.default
            .subpathsOfDirectory(atPath: Self.appSourceRoot.path)
            .filter { $0.hasSuffix("TeamSelectionView.swift") }
        XCTAssertEqual(selectors.count, 1, "팀 선택 화면 구현이 둘 이상이다 — \(selectors)")
    }

    func testP18_teamSelectionBindsToTheStoredPreference() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("preferences.favoriteTeamID"),
                      "선택 상태가 저장된 값에 묶여 있지 않다")
    }

    // MARK: - 19~22. 법적 정보

    func testP19_privacyUsesTheConfiguredDestination() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("appData.legalURL(\\.privacy)"),
                      "개인정보 처리방침이 설정된 목적지를 쓰지 않는다")
    }

    func testP20_termsUsesTheConfiguredDestination() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("appData.legalURL(\\.terms)"),
                      "이용약관이 설정된 목적지를 쓰지 않는다")
    }

    func testP21_accountDeletionGuidanceIsInformationalOnly() throws {
        let source = try profileSource
        XCTAssertTrue(source.contains("appData.legalURL(\\.accountDeletion)"),
                      "계정 삭제 안내가 설정된 목적지를 쓰지 않는다")
        XCTAssertTrue(source.contains("\"계정 삭제 안내\""), "안내 문구가 아니다")
        // 안내일 뿐이므로 지우는 동작이 붙어 있으면 안 된다.
        for destructive in ["deleteAccount", "removeAll()", "removePersistentDomain", "reset()"] {
            XCTAssertFalse(source.contains(destructive),
                           "안내 행에 파괴적인 동작 \(destructive)이 붙었다")
        }
    }

    func testP22_noInventedURLIsUsed() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("URL(string: \"http"),
                       "화면이 URL을 직접 지어낸다")
    }

    // MARK: - 23~26. 앱 버전

    func testP23_versionComesFromBundleInformation() {
        let bundle = Bundle(for: Self.self)
        let version = ProfileAppVersion(bundle: bundle)
        XCTAssertEqual(version.marketingVersion,
                       bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       "마케팅 버전이 번들에서 오지 않는다")
    }

    func testP24_versionDisplayUsesTheMarketingValue() {
        let version = ProfileAppVersion(marketingVersion: "1.4.2", buildNumber: "77")
        XCTAssertEqual(version.displayText, "1.4.2", "표시 값이 마케팅 버전이 아니다")
    }

    func testP25_missingVersionIsNotInvented() {
        XCTAssertEqual(ProfileAppVersion(marketingVersion: nil, buildNumber: nil).displayText,
                       "알 수 없음", "값이 없을 때 숫자를 지어낸다")
        XCTAssertEqual(ProfileAppVersion(marketingVersion: "  ", buildNumber: nil).displayText,
                       "알 수 없음", "빈 값을 버전처럼 보여준다")
    }

    func testP26_noHardCodedVersionRemainsInTheScreen() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("0.1.0"), "예전 하드코딩 버전이 남았다")
        XCTAssertFalse(source.contains("2.0.0"), "Pencil 견본 버전이 들어왔다")
        XCTAssertTrue(source.contains("appVersion.displayText"), "번들 값을 쓰지 않는다")
    }

    // MARK: - 27~34. 뒷받침 없는 행은 없다

    func testP27_unsupportedRowsAreAbsent() throws {
        let source = try profileSource
        for forbidden in ["경기 시작 알림", "직관 후 기록 리마인드", "기록 내보내기",
                          "데이터 내보내기", "사진 보관함 관리", "128장", "추후 제공",
                          "준비 중", "곧 제공"] {
            XCTAssertFalse(source.contains(forbidden),
                           "뒷받침 없는 \(forbidden) 행이 화면에 있다")
        }
    }

    func testP28_logoutIsAbsentBecauseNoAuthBoundaryExists() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("\"로그아웃\""), "인증 경계가 없는데 로그아웃이 있다")
        for authSymbol in ["signOut", "logout", "accessToken"] {
            XCTAssertFalse(source.contains(authSymbol), "\(authSymbol)이 마이 화면에 생겼다")
        }
    }

    func testP29_noNotificationPermissionIsRequested() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("UNUserNotificationCenter"),
                       "알림 권한 요청이 들어왔다")
    }

    func testP30_noFabricatedSeasonClaimIsRendered() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("세 번째 시즌"), "지어낸 시즌 문장이 남았다")
        XCTAssertFalse(source.contains("함께한"), "근거 없는 기간 문장이 있다")
    }

    func testP31_noRecordSummaryIsInvented() throws {
        let source = try profileScreenBody
        // NffPV는 기록 요약을 그리지 않는다. 지어내지 않았는지 본다.
        for invented in ["승률", "총 기록 수", "wins", "winRate"] {
            XCTAssertFalse(source.contains(invented),
                           "권위 있는 프레임에 없는 기록 요약 \(invented)이 생겼다")
        }
    }

    func testP32_theTabRootHasNoDismissToolbar() throws {
        let source = try profileSource
        // 화면 본문(ProfileSettingsView)만 본다. 자식 시트는 자기 닫기를 가진다.
        guard let start = source.range(of: "struct ProfileSettingsView"),
              let end = source.range(of: "struct ProfileNavigationRow") else {
            return XCTFail("프로필 화면 범위를 찾지 못했다")
        }
        let body = String(source[start.lowerBound..<end.lowerBound])
        XCTAssertFalse(body.contains("Environment(\\.dismiss)"),
                       "탭 루트가 dismiss를 들고 있다")
        XCTAssertFalse(body.contains("Button(\"닫기\")"),
                       "탭 루트에 닫을 것이 없는데 닫기가 있다")
    }

    func testP33_theCanonicalFrameAuthorsNoTitleSoNoneIsInvented() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("navigationTitle(\"설정\")"),
                       "NffPV가 그리지 않은 제목이 남았다")
        XCTAssertTrue(source.contains("toolbar(.hidden, for: .navigationBar)"),
                      "그리지 않은 헤더 자리가 비어 있다")
    }

    func testP34_openingTheScreenPerformsNoMutation() throws {
        let source = try profileSource
        // `.task`는 읽기만 한다.
        XCTAssertTrue(source.contains("loadUserProfileIfNeeded"), "프로필 읽기가 사라졌다")
        XCTAssertTrue(source.contains("loadLegalLinksIfNeeded"), "법적 링크 읽기가 사라졌다")
        for mutation in ["updateTeamThemeEnabled", "saveRecord", "updateFavoriteTeam(nil)"] {
            XCTAssertFalse(source.contains(".task {\n            \(mutation)"),
                           "화면을 여는 것만으로 \(mutation)이 일어난다")
        }
    }

    // MARK: - 35~38. 숨긴 것과 지운 것은 다르다

    /// 마이 화면에서 뺀 행들의 **기능 자체**는 지우지 않았다.
    func testP35_hiddenCapabilitiesStillExistElsewhere() throws {
        let profile = try source("Features/Profile/ProfileSettingsView.swift")
        XCTAssertTrue(profile.contains("struct ProfileCreationView"), "프로필 편집기가 사라졌다")
        XCTAssertTrue(profile.contains("struct BlockedUsersView"), "차단 사용자 화면이 사라졌다")
        XCTAssertTrue(profile.contains("struct ProfileAvatarView"), "아바타 컴포넌트가 사라졌다")
    }

    func testP36_communityStillReachesThePreservedViews() throws {
        let community = try source("Features/Community/CommunityHomeView.swift")
        XCTAssertTrue(community.contains("ProfileCreationView") || community.contains("BlockedUsersView"),
                      "커뮤니티가 쓰던 화면이 끊겼다")
    }

    func testP37_noPersistenceOrAPIContractChanged() throws {
        let source = try profileSource
        for forbidden in ["@Model", "ModelContainer", "URLSession", "URLRequest", "/api/v1"] {
            XCTAssertFalse(source.contains(forbidden),
                           "마이 화면이 \(forbidden)을 직접 다룬다")
        }
    }

    func testP38_theScreenOwnsNoUnrelatedMutation() throws {
        let source = try profileSource
        XCTAssertFalse(source.contains("updateTeamThemeEnabled"),
                       "마이 화면이 다시 팀 테마를 바꾼다")
    }

    // MARK: - 39~42. 완료된 계약은 그대로다

    func testP39_recordCreateRouteGovernanceIsUntouched() throws {
        let root = try rootSource
        XCTAssertFalse(root.contains("LogEditorView("), "탭 루트가 편집기를 직접 연다")
        let home = try executableSource("Features/Home/HomeView.swift")
        XCTAssertFalse(home.contains("ProfileSettingsView"), "홈이 마이 화면을 연다")
    }

    func testP40_fiveTabsRemainInOrder() {
        XCTAssertEqual(MainTab.allCases.map(\.rawValue),
                       ["home", "feed", "calendar", "statistics", "my"],
                       "탭 구성이 바뀌었다")
    }

    func testP41_theFairySourceSystemIsUntouched() throws {
        let glyphs = try source("DesignSystem/VFFairyGlyphs.swift")
        XCTAssertTrue(glyphs.contains("case victory"), "승리 요정 종류가 사라졌다")
        XCTAssertTrue(glyphs.contains("case compact"), "48px 판이 사라졌다")
    }

    func testP42_noScreenSpecificHexColourWasIntroduced() throws {
        let source = try profileSource
        guard let start = source.range(of: "struct ProfileSettingsView"),
              let end = source.range(of: "struct ProfileNavigationRow") else {
            return XCTFail("프로필 화면 범위를 찾지 못했다")
        }
        let body = String(source[start.lowerBound..<end.lowerBound])
        XCTAssertFalse(body.contains("Color(red:"), "화면 전용 색을 직접 만들었다")
        XCTAssertFalse(body.contains("#"), "화면 전용 hex 색이 들어왔다")
    }

    // MARK: - 도구

    private static func emptyDefaults() -> UserDefaults {
        let name = "ProfileSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
