import Foundation

/// 화면이 보여 줄 앱 버전.
///
/// 예전 마이 화면은 `승리요정 0.1.0`을 글자로 적어 두었다. 릴리스가 올라가도
/// 그 숫자는 그대로였으니, 화면이 사실이 아닌 것을 말하고 있었다. Pencil이 그려
/// 둔 `2.0.0`도 견본일 뿐이라 같은 문제를 만든다.
///
/// 그래서 값은 번들에서만 온다. 테스트가 번들 없이도 규칙을 확인할 수 있게
/// 읽는 곳만 좁게 감싼다 — 이 하나를 위해 전역 의존성 컨테이너를 만들지 않는다.
struct ProfileAppVersion: Equatable {
    /// `CFBundleShortVersionString`. 사용자에게 보이는 마케팅 버전.
    let marketingVersion: String?
    /// `CFBundleVersion`. 빌드 번호.
    let buildNumber: String?

    /// 실제 제품이 쓰는 값.
    static let bundle = ProfileAppVersion(bundle: .main)

    init(marketingVersion: String?, buildNumber: String?) {
        self.marketingVersion = marketingVersion
        self.buildNumber = buildNumber
    }

    init(bundle: Bundle) {
        self.init(
            marketingVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    /// 화면에 적히는 문자열.
    ///
    /// 마케팅 버전만 말한다. 빌드 번호는 사용자에게 뜻이 없고, 두 값을 붙이면
    /// 스토어에 보이는 버전과 달라 보인다. 번들이 값을 주지 않는 경우는 제품에서
    /// 일어나지 않지만, 그때도 숫자를 지어내지 않고 모른다고 말한다.
    var displayText: String {
        let trimmed = marketingVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return "알 수 없음" }
        return trimmed
    }
}
