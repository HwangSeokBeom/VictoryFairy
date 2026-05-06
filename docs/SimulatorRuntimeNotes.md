# Simulator Runtime Notes

## benign simulator warning

- `objc: Class UIAccessibilityLoaderWebShared is implemented in both WebKit and WebCore...`
  - 앱에서 WebView를 직접 사용하지 않고 크래시가 없다면 iOS Simulator 런타임 경고로 분류한다.
- `Failed to send CA Event for app launch measurements...`
  - 앱 실행 측정 이벤트 전송 실패로, 크래시나 앱 코드의 네트워크 실패로 보지 않는다.
- `UIKeyboardLayoutStar implements focusItemsInRect...`
  - 키보드/포커스 런타임 쪽 경고로, 입력 UI가 실제로 깨지거나 크래시가 있을 때만 앱 이슈로 추적한다.
- `IOSurfaceClientSetSurfaceNotify failed e00002c7`
  - 화면 렌더링이 정상이고 크래시가 없다면 Simulator graphics/runtime 경고로 분류한다.

## 앱 리소스 접근 점검

- 현재 앱 코드는 `Bundle.main.url(forResource:)`, `UIImage(named:)`, 직접 파일 경로 접근, seed JSON 로딩을 사용하지 않는다.
- 팀 seed는 Swift 코드의 `KBOSeed`로 제공되며, 이미지도 SF Symbols 기반 `Image(systemName:)`만 사용한다.
- 따라서 현재 확인된 `fopen failed for data file: errno = 2`는 앱 번들 리소스 누락으로 재현되는 지점이 없다.
- 이후 seed JSON, asset catalog image, placeholder photo, string catalog를 추가할 때는 missing resource를 fatal error로 처리하지 말고 sample fallback 또는 빈 상태 UI로 내려야 한다.
