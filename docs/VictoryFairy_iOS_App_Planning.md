# 승리요정 iOS 앱 기획 문서

작성일: 2026-05-01  
대상 플랫폼: iOS 네이티브 앱  
개발 가정: Swift, SwiftUI, 로컬 저장 우선, 서버 없음  
문서 목적: MVP 개발 착수 전 제품 방향, 화면 구조, 데이터 구조, 구현 우선순위를 정리한다.

> 중요 전제: KBO 팀/구장/일정/결과 정보는 시즌별로 변경될 수 있다. 실제 구현 직전에는 반드시 [KBO 공식 사이트](https://www.koreabaseball.com/), 구단 공식 사이트, 앱스토어/플레이스토어의 공식 KBO 앱 정보 등 신뢰 가능한 출처로 재확인해야 한다. 외부 경기 데이터는 저작권과 이용약관 이슈가 있으므로 MVP는 크롤링이 아닌 수동 입력과 앱 내 기본 seed 데이터 중심으로 설계한다.

## 1. 서비스 개요

### 한 줄 소개

승리요정은 KBO 팬을 위한 직관 시즌 다이어리 앱이다. 직관한 경기를 피드처럼 남기고, 캘린더에서 시즌을 되돌아보며, 나의 직관 승률과 구장별 성적을 데이터로 확인한다.

제품 컨셉은 "KBO 직관 버전의 Instagram + Calendar + Personal Sports Data Diary"다. 단, 초기 MVP에서 SNS 커뮤니티를 바로 구현한다는 뜻은 아니다. MVP에서는 개인 기록을 예쁜 post/card로 남기고, 시즌 캘린더에서 날짜별 직관을 회고하며, 홈과 통계에서 나의 직관 데이터를 해석하는 데 집중한다. 추후 공유 카드, SNS 공유, 친구 피드로 확장할 수 있는 구조를 남긴다.

서비스 경험의 3대 축은 다음과 같다.

1. 피드형 기록: 사진, 결과, 점수, 구장, 다이어리 캡션, 태그를 하나의 직관 post처럼 보여준다.
2. 캘린더형 회고: 내가 간 경기들이 시즌 캘린더에 날짜별로 찍히고, 월별 흐름을 되돌아본다.
3. 데이터형 통계: 승리요정 지수, 승률, 구장별/상대팀별/시즌별 성적을 분석한다.

승리요정은 정량 데이터인 직관 기록과 정성 데이터인 직관 다이어리를 함께 다룬다. 사용자가 긴 후기를 처음부터 쓰지 않아도 경기 정보, 분위기, 하이라이트, 감정을 바탕으로 AI가 직관 후기 초안을 제안할 수 있지만, AI는 사용자의 기록을 대신 작성하는 존재가 아니라 기억을 정리해주는 보조 도구다. MVP 1차에서는 수동 메모와 다이어리 입력을 우선하고, MVP 1.5차에서는 로컬 템플릿 기반 문장 생성을 제공할 수 있다. LLM 기반 AI 작성은 서버/보안/비용 제어 설계가 준비된 뒤 확장한다.

### 앱의 핵심 가치

- 기록하는 재미: 경기별 post/card로 직관한 날을 예쁘게 남긴다.
- 돌아보는 재미: 시즌 캘린더에서 내가 간 경기와 결과 흐름을 날짜별로 되짚는다.
- 분석하는 재미: "내가 가면 이기나?"라는 팬덤의 재미를 승률, 연승, 구장별 성적, 상대팀별 성적 등으로 보여준다.
- 공유하는 재미: 초기에는 개인 기록 중심으로 만들되, 추후 공유 카드와 SNS 공유로 확장한다.
- 서버 없이도 빠르게 시작할 수 있는 개인 데이터 앱으로 만들고, 이후 동기화/공유/공식 데이터 연동까지 확장 가능하게 설계한다.

### 사용자가 이 앱을 쓰는 이유

- 직관한 경기를 시즌별로 잊지 않고 남기고 싶다.
- 응원팀이 내가 간 경기에서 얼마나 이겼는지 알고 싶다.
- 어느 구장, 어느 상대팀, 어느 요일에 승률이 좋은지 궁금하다.
- 티켓 사진, 좌석, 같이 간 사람, 한 줄 메모를 한 곳에 모으고 싶다.
- 긴 글을 쓰기 부담스러울 때도 짧은 메모나 보조 초안으로 그날의 감정을 남기고 싶다.
- 시즌이 끝났을 때 "나의 직관 리포트"를 보고 공유하고 싶다.

### 기존 야구 앱과 다른 점

기존 야구 앱은 일정, 실시간 중계, 기록, 기사, 티켓 등 리그와 팀 중심의 정보를 제공한다. 승리요정은 공식 기록을 대체하지 않고, "내가 실제로 본 경기"만을 중심으로 개인화된 직관 데이터를 만든다. 핵심 주어가 리그/팀이 아니라 사용자다.

### 기존 다이어리 앱과 다른 점

일반 다이어리는 자유 기록에 강하지만 야구 경기의 구조화된 데이터에는 약하다. 승리요정은 날짜, 시즌, 응원팀, 상대팀, 구장, 결과, 점수, 좌석, 태그를 정형 데이터로 저장해 자동 통계를 만든다.

### "야구는 데이터 스포츠" 관점을 앱 기능에 녹이는 방법

- 모든 직관 로그를 통계 계산 가능한 구조로 저장한다.
- 승/패/무/취소, 득점/실점, 구장, 상대팀, 요일, 월, 좌석, 동행자를 분석 축으로 둔다.
- 홈 화면에서 누적 기록, 최근 흐름, 승리요정 지수를 즉시 보여준다.
- 통계 화면은 단순 숫자보다 "해석 가능한 카드" 중심으로 구성한다.

### KBO 직관 팬에게 특히 필요한 이유

KBO 팬덤은 응원팀, 응원석, 구장 음식, 동행, 원정, 징크스 같은 직관 문화가 강하다. "내가 가면 이긴다/진다", "이 구장만 가면 좋다", "올해 몇 번 갔나" 같은 대화가 자연스럽기 때문에 개인 직관 데이터를 쌓는 앱의 반복 사용 동기가 명확하다.

### 초기 MVP에서 반드시 가져가야 할 핵심 경험

1. 30초 안에 직관 로그를 등록한다.
2. 홈에서 이번 시즌 요약, 승리요정 지수, 최근 직관을 본다.
3. 피드에서 내가 간 경기를 Instagram-like 직관 카드로 다시 본다.
4. 캘린더에서 월별 직관 날짜와 결과 흐름을 확인한다.
5. 통계 화면에서 구장별, 상대팀별, 시즌별 성적을 확인한다.

### 나중에 확장 가능한 방향

- 사진 기반 티켓/스코어보드 OCR 보조 입력
- 경기 일정/결과 합법 API 연동 또는 제휴 데이터
- iCloud 백업, 계정 동기화, 위젯, 공유 이미지
- 서버 기반 LLM 직관 다이어리 초안 생성, 시즌 회고 문구 생성
- 친구와 직관 기록 공유, 그룹 직관, 랭킹
- 시즌 리포트, 구장 도장깨기, 배지, 챌린지

## 2. 레퍼런스 조사

### 참고 출처

- KBO 공식 구단 소개: [koreabaseball.com teaminfo](https://www.koreabaseball.com/kbo/league/teaminfo.aspx)
- KBO 공식 앱 정보: [KBO - Google Play](https://play.google.com/store/apps/details?id=com.sports2i.kbo)
- MLB Ballpark 공식 소개: [MLB Ballpark](https://www.mlb.com/apps/ballpark)
- Strava 활동/소셜 기능: [Strava Support](https://support.strava.com/hc/en-us/articles/5999524455053-My-Activities-Are-Set-to-Everyone-Where-Does-That-Data-Go-on-Strava)
- Letterboxd 공식 소개: [Letterboxd](https://letterboxd.com/)
- GameChanger 기능 소개: [GameChanger App Features](https://gc.com/app-features)
- Goodreads 서비스 개요: [Goodreads](https://www.goodreads.com/)

### 레퍼런스 분석

| 서비스명 | 핵심 기능 | 반복적으로 여는 이유 | 기록 방식 | 통계/분석 방식 | 커뮤니티/공유 | 승리요정에 참고할 점 | 따라 하지 않아도 되는 점 | MVP 반영 아이디어 | 장기 확장 아이디어 |
|---|---|---|---|---|---|---|---|---|---|
| MLB Ballpark | 티켓, 구장 정보, 체크인, 방문 히스토리 | 경기 당일 티켓/구장 정보 확인 | 티켓 기반 방문, My History | 방문 경기 날짜/스코어/하이라이트 | 티켓 공유, 구장 경험 | 직관 히스토리를 별도 자산으로 다루는 방식 | 티켓 결제/입장 기능은 MVP 범위 밖 | 경기 방문 히스토리와 사진/스코어 기록 | 위치 기반 체크인, 티켓 연동 |
| KBO 공식 앱 | 일정, 기록, 뉴스, 푸시, 공식 정보 | 경기 일정/결과/기록 확인 | 사용자가 직접 로그를 남기는 구조는 아님 | 리그/팀/선수 공식 기록 | 일부 커뮤니티/알림 | 공식 데이터의 기준점과 용어 | 공식 앱의 정보 포털 역할 전체 | KBO 팀/구장 seed 데이터 재확인 출처 | 공식/제휴 데이터 연동 |
| GameChanger | 경기 스코어링, 팀 관리, 시즌 통계 | 팀 경기 운영과 기록 확인 | 이닝/플레이 단위 기록 | 팀/선수 시즌 통계 | 팀 채팅, 가족 팬 기능 | 야구 데이터 입력을 구조화하는 방식 | 플레이 단위 스코어링은 과함 | 점수/결과/태그만 단순 입력 | 선발투수/특이 경기 태그 분석 |
| Strava | 운동 기록, 피드, 세그먼트, 챌린지 | 활동 업로드, 성과 비교, 친구 피드 | GPS/수동 활동 로그 | 거리/속도/구간/챌린지 | 팔로우, 클럽, 리더보드 | 개인 활동을 누적 데이터와 성취로 전환 | 위치 추적 기반 경쟁은 초기 불필요 | 시즌 목표, 누적 직관 횟수 | 구장 도장깨기, 친구 랭킹 |
| Letterboxd | 영화 감상 기록, 평점, 다이어리, 리스트 | 본 영화 기록, 리뷰, 친구 활동 | 감상 날짜, 별점, 리뷰, 태그 | 연간 통계, 장르/감독/배우 통계 | 팔로우, 리뷰 공유 | "기록-피드-통계-공유" 루프 | 공개 리뷰 중심 커뮤니티는 후순위 | 피드형 기록, 태그, 시즌 통계 | 연말 직관 리포트, 공유 카드 |
| Goodreads | 독서 기록, 책장, 리뷰, 독서 챌린지 | 읽는 중/읽음 관리, 목표 추적 | 상태, 평점, 리뷰, 책장 | 연간 독서 목표와 진행률 | 친구, 리뷰, 그룹 | 시즌 목표와 진행률 UX | 콘텐츠 추천은 MVP 불필요 | "올 시즌 직관 목표" | 시즌 챌린지, 배지 |
| Swarm/Foursquare 계열 체크인 | 장소 체크인, 방문 히스토리 | 방문 장소 기록, 배지 | 위치/장소 기반 체크인 | 장소별 방문 횟수 | 친구 체크인 | 구장 방문 횟수와 도장깨기 | 실시간 위치 인증은 초기 불필요 | 구장별 방문 횟수 | 위치 기반 구장 체크인 |
| 티켓 예매 앱 | 경기 티켓 구매/보관 | 예매, 좌석 확인 | 예매 내역 중심 | 구매/관람 이력 제한적 | 티켓 전달 | 좌석 정보가 직관 경험의 핵심 데이터 | 결제/예매는 범위 밖 | 좌석 구역/열/번호 선택 입력 | 티켓 이미지 OCR, 예매처 딥링크 |
| 팬덤 커뮤니티 앱 | 게시글, 댓글, 응원, 밈 | 경기 전후 대화와 정보 교류 | 게시글 중심 | 커뮤니티 반응 지표 | 강함 | 공유 이미지/직관 인증의 바이럴 가능성 | 초반부터 커뮤니티 운영 리스크 | 개인 기록 공유 이미지 | 친구 피드, 그룹 직관 |

### 핵심 인사이트

- 승리요정은 공식 경기 정보 앱이 아니라 개인 활동 기록 앱에 가깝다.
- Strava/Letterboxd처럼 "기록하면 내 프로필과 통계가 풍부해지는 구조"가 반복 사용의 핵심이다.
- MLB Ballpark의 Fan History는 직관 앱의 직접 레퍼런스지만, 승리요정은 티켓보다 팬의 개인 데이터와 승률 재미를 더 강조해야 한다.
- MVP는 자동화보다 빠른 수동 입력이 중요하다. 외부 데이터 자동 매칭은 법적/기술적 리스크가 낮아진 뒤 붙인다.

## 3. 타깃 사용자

### 초기 사용자 정의

- KBO 직관을 한 시즌에 여러 번 가는 팬
- 응원팀의 직관 승률을 직접 계산해보고 싶은 팬
- 야구장 방문 기록과 사진을 남기고 싶은 팬
- 내가 가면 이기는지 지는지 궁금한 팬
- 구장별 추억과 원정 기록을 관리하고 싶은 팬
- 시즌별 직관 횟수와 승패를 보고 싶은 팬
- 친구들과 직관 인증 이미지를 공유하고 싶은 팬

### 사용자 페르소나

| 사용자 유형 | 주요 니즈 | 현재 불편함 | 해결할 문제 | 자주 사용할 기능 | 계속 쓰는 동기 |
|---|---|---|---|---|---|
| 홈구장 단골 팬 | 시즌 직관 횟수와 승률 확인 | 메모장/사진첩에 흩어짐 | 직관 기록 통합 관리 | 빠른 로그 등록, 홈 대시보드 | 승률과 최근 흐름 확인 |
| 원정 직관 팬 | 구장별 방문/성적 기록 | 어느 구장에 언제 갔는지 기억 어려움 | 구장별 히스토리와 도장깨기 | 구장별 통계, 지도 확장 | 구장 컬렉션 완성 |
| 데이터형 야구 팬 | 상대팀/요일/좌석별 패턴 분석 | 직접 스프레드시트 관리가 귀찮음 | 자동 통계 계산 | 통계 화면, 필터 | "내 데이터"가 쌓이는 재미 |
| 감성 기록형 팬 | 사진, 동행자, 한 줄 메모 보관 | 일반 앨범은 경기 맥락 부족 | 경기 단위 추억 정리 | 사진 첨부, 상세 화면 | 시즌 종료 후 회고 |
| 공유형 팬 | 직관 결과를 친구에게 보여주기 | 캡처/수동 편집 필요 | 예쁜 공유 카드 생성 | 홈 요약, 공유 이미지 | SNS 인증과 대화 소재 |

## 4. 핵심 가치 제안

### 핵심 가치 제안

1. 기록하는 재미: 직관한 경기를 경기별 post/card로 남겨 "내 시즌 피드"를 만든다.
2. 돌아보는 재미: 시즌 캘린더에서 날짜별 직관과 결과 흐름을 한눈에 회고한다.
3. 분석하는 재미: 승률, 승리요정 지수, 구장/상대팀/시즌별 성적을 자동 정리한다.
4. 공유하는 재미: 초기에는 공유 placeholder와 preview를 준비하고, 추후 SNS 공유 카드와 친구 피드로 확장한다.
5. 수동 입력만으로도 시작할 수 있어 데이터 권리 리스크가 낮다.

### 감정적 가치

- "올해 나 이만큼 갔다"는 성취감
- 내 직관 기록이 하나의 시즌 앨범처럼 쌓이는 만족감
- "내가 가면 이긴다"는 팬덤 특유의 장난스러운 자부심
- 경기장의 기억을 시즌 단위로 다시 보는 회고감
- 친구와 비교하거나 공유하고 싶은 재미

### 실용적 가치

- 직관 횟수, 승률, 구장별 성적 자동 계산
- 사진/좌석/동행자/캡션/다이어리의 경기 단위 정리
- 시즌별 기록 필터링
- 월별 캘린더 기반 탐색
- 수동 기록 기반이라 인터넷 연결 없이도 핵심 기능 사용 가능

### 팬덤 문화와 연결되는 가치

- 응원팀 중심 정체성
- 원정, 응원석, 동행, 징크스 같은 팬 문화 데이터화
- 공유 이미지로 경기 후 대화 소재 생성

### 데이터 기반 기록 앱으로서의 가치

단순히 "오늘 야구 봄"을 남기는 것이 아니라, 시간이 지날수록 피드, 캘린더, 통계가 함께 풍성해지는 앱이다. 입력 데이터가 많아질수록 사용자는 시즌의 기억과 데이터 인사이트를 동시에 얻는다.

## 5. MVP 기능 정의

### MVP 1차 필수 기능

MVP 1차에는 LLM 기반 AI 기능을 넣지 않는다. 단, AI 없이도 사용할 수 있는 한 줄 메모와 직관 다이어리 입력 필드는 처음부터 설계에 포함한다.

| 기능 | 판단 | 이유 |
|---|---|---|
| 직관 경기 등록 | 필수 | 앱의 핵심 입력 루프 |
| 직관 로그 CRUD | 필수 | 등록/조회/수정/삭제가 개인 기록 앱의 기본 |
| 경기 날짜 선택 | 필수 | 시즌/요일/월별 통계의 기준 |
| 응원팀 선택 | 필수 | 승패 판정과 개인화 기준 |
| 상대팀 선택 | 필수 | 상대팀별 통계 기준 |
| 구장 선택 | 필수 | 구장별 성적과 방문 기록 기준 |
| 경기 결과 입력: 승/패/무/취소 | 필수 | 승률 계산의 핵심 |
| 점수 입력 | 필수에 가까움 | 평균 득실점, 경기 상세 정보 |
| 경기 한 줄 메모 | 필수 | AI 없이도 동작하는 감성 기록 최소 단위 |
| 직관 다이어리 입력 필드 | 필수 | 사용자가 직접 긴 후기를 남길 수 있는 기본 기록 경험 |
| 홈 요약 | 필수 | 이번 시즌 요약, 승리요정 지수, 최근 직관 확인 |
| 피드형 로그 카드 | 필수 | 기록을 단순 리스트가 아니라 post/card 경험으로 전환 |
| 기본 캘린더 진입 또는 최소 month view | 필수 | 캘린더를 핵심 경험으로 인식시키는 최소 구현 |
| 경기 상세 화면 | 필수 | 기록 확인/수정 |
| 직관 승률 통계 | 필수 | 앱의 핵심 가치 |
| 시즌별 직관 기록 | 필수 | KBO 시즌 맥락 |
| 구장별 직관 성적 | 필수 | 직관 앱 차별점 |
| 팀별 상대 전적 | 필수 | 야구 데이터 앱 느낌 |

### MVP 1.5차 기능

| 기능 | 이유 |
|---|---|
| 좌석 정보 입력 | 유용하지만 필수 통계 이후에도 가능 |
| 같이 간 사람 메모 | 재미있는 통계 축이나 초기 입력 부담 증가 |
| 경기 사진 첨부 | 피드 카드의 하이파이 품질을 크게 높이지만 권한/저장/용량 처리가 필요 |
| 월별 직관 횟수 | 구현 쉬우며 통계 화면 보강 |
| 캘린더 상세 bottom sheet | 날짜별 경기 확인과 기록 추가 흐름을 자연스럽게 연결 |
| 태그 입력 | 피드형 기록과 특이 경기 분석에 좋지만 초기 태그 체계 필요 |
| 템플릿 기반 직관 다이어리 자동 문장 생성 | 외부 API 없이 로컬 문자열 조합으로 구현 가능. 예: "오늘은 {구장}에서 {응원팀} 경기를 직관했다. 결과는 {점수} {결과}." |
| 분위기/하이라이트/말투 선택 UI | LLM 없이도 다이어리 템플릿 품질을 높이고, 이후 AI 기능 입력값으로 재사용 가능 |
| 공유 카드 preview | 실제 공유 기능 전에도 디자인 방향과 바이럴 포맷을 검증 가능 |

### 추후 확장 기능

- AI 후기 초안
- SNS 공유 이미지
- 시즌 리포트
- 친구 피드/공유 기능
- iCloud 백업/동기화
- 위젯
- LLM 기반 AI 직관 다이어리 초안 생성
- 말투 선택: 담백하게 / 감성적으로 / 유쾌하게 / SNS 캡션처럼
- 분위기 선택: 짜릿함 / 아쉬움 / 편안함 / 열광적 / 분노 / 감동
- 하이라이트 선택: 홈런 / 역전승 / 끝내기 / 연장전 / 호수비 / 응원 분위기 / 우천 취소
- AI 결과물: 한 줄 요약, 직관 다이어리 본문, SNS 공유용 짧은 문구, 해시태그 후보
- 친구/그룹 직관
- 경기 일정/결과 후보 추천
- 티켓 이미지 OCR
- 선수/선발투수 기반 메모 분석
- 구장 지도/도장깨기

### 지금은 제외해도 되는 기능

- 실시간 문자중계
- 플레이 단위 스코어링
- 티켓 예매/결제
- 공식 선수 기록 데이터 자동 수집
- 커뮤니티 게시판
- 랭킹/친구 피드
- 서버 계정 시스템
- MVP 1차의 LLM 기반 AI 기능
- 사진 자체를 LLM에 보내는 기능
- 위치 원문, 동행자 실명, 민감한 메모를 그대로 AI에 보내는 기능
- 자동 저장되는 AI 일기
- 사용자가 검토하지 않은 AI 생성 글의 자동 공유

## 6. 데이터 스포츠 관점의 기능 아이디어

| 기능명 | 설명 | 필요한 입력 데이터 | 계산 방식 | 화면 | MVP | 재미 요소 | 한계 |
|---|---|---|---|---|---|---|---|
| 나의 직관 승률 | 내가 등록한 전체 경기 승률 | 결과 | 승 / (승+패) | 홈, 통계 | 포함 | 승리요정 핵심 | 표본 적으면 왜곡 |
| 구장별 승률 | 구장마다 승률 비교 | 구장, 결과 | 구장별 승/(승+패) | 통계, 구장 상세 | 포함 | "내 성지 구장" | 중립 경기 주의 |
| 상대팀별 승률 | 상대팀 기준 성적 | 상대팀, 결과 | 상대별 승/(승+패) | 통계 | 포함 | 강한/약한 상대 | 응원팀 변경 시 기준 필요 |
| 시즌별 승률 | 시즌별 내 직관 성적 | 날짜, 결과 | 연도별 승/(승+패) | 시즌 통계 | 포함 | 시즌 회고 | 포스트시즌 구분 필요 |
| 요일별 승률 | 요일별 패턴 | 날짜, 결과 | 요일별 승률 | 통계 | 1.5 | "금요일 요정" | 우연성이 큼 |
| 월별 직관 횟수 | 월별 방문량 | 날짜 | 월별 count | 통계, 캘린더 | 1.5 | 직관 루틴 확인 | 승률과 분리 필요 |
| 좌석 구역별 승률 | 좌석 위치와 결과 비교 | 좌석, 결과 | 좌석 키워드별 승률 | 좌석 통계 | 확장 | "1루 네이비석 승률" | 입력 표준화 어려움 |
| 동행자별 승률 | 같이 간 사람별 결과 | 동행자, 결과 | 동행자별 승률 | 동행자 통계 | 확장 | 진짜 승리요정 찾기 | 개인정보/동의 |
| 평균 득점/실점 | 직관 경기 득실 경향 | 점수 | 득점 평균, 실점 평균 | 통계 | 포함 | 화끈한 경기 선호 | 취소/미입력 제외 |
| 특이 경기 태그 | 끝내기/연장/역전승 등 | 태그, 결과 | 태그별 count/승률 | 상세, 통계 | 1.5 | 기억에 남는 경기 | 태그 입력 부담 |
| 연승/연패 | 직관 기준 흐름 | 날짜, 결과 | 날짜순 결과 streak | 홈 | 포함 | 현재 기운 표현 | 무/취소 처리 정책 필요 |
| 가장 많이 간 구장 | 최다 방문 구장 | 구장 | 구장별 count max | 홈, 통계 | 포함 | 구장 애착 | 홈팬 편향 |
| 가장 많이 본 상대팀 | 최다 상대 | 상대팀 | 상대팀별 count max | 통계 | 포함 | 라이벌 체감 | 일정 편향 |
| 승리요정 지수 | 승률+표본 보정 점수 | 결과, 경기 수 | 보정 승률 점수화 | 홈 | 포함 | 앱 네이밍 연결 | 공식 예측 아님 |

## 7. 화면 구조

### 추천 탭 구조

초기 버전은 4개 탭을 추천한다. 기존 `홈 / 로그 / 통계 / 설정` 구조는 제품 정체성이 기록/통계 앱처럼 보이는 문제가 있으므로, `로그`를 `피드`로 재정의하고 `캘린더`를 핵심 탭으로 승격한다. `설정`은 독립 하단 탭에서 제거하고 홈 우측 상단 프로필/설정 아이콘으로 진입한다.

| 탭 이름 | 목적 | 주요 화면 | 핵심 컴포넌트 | 행동 | MVP 포함 | 추후 확장 |
|---|---|---|---|---|---|---|
| 홈 | 이번 시즌 상태 요약 | HomeDashboardView | 시즌 요약, 승리요정 지수, 최근 직관, 빠른 기록 추가 | 기록 추가, 최근 경기 진입, 프로필/설정 진입 | 포함 | 공유 카드, 위젯 진입 |
| 피드 | 직관 기록을 post/card로 감상 | FeedView, AttendancePostCard | 사진/스코어보드 header, 캡션, 태그, 결과 필터 | 상세 보기, 수정, 공유 preview | 포함 | 친구 피드, 공개/비공개 |
| 캘린더 | 날짜 기반 시즌 회고 | CalendarView, CalendarDayDetailBottomSheet | 월별 그리드, result dot, 날짜별 경기 sheet | 날짜 선택, 해당 날짜 기록 추가 | 포함 | 더블헤더 배지, 시즌 히트맵 |
| 통계 | 데이터 분석 | StatisticsView | 승률, 구장/상대팀/시즌별 분석, 차트, 순위 | 기간 선택, 상세 분석 | 포함 | 고급 필터, 시즌 리포트 |

### 프로필/설정 진입

설정은 하단 탭이 아니라 홈 우측 상단의 프로필/설정 아이콘에서 진입한다. `ProfileSettingsView`에는 응원팀 변경, 데이터 저장 안내, 앱 정보, AI 개인정보 안내, 내보내기 placeholder를 포함한다. 이렇게 해야 하단 탭은 사용자가 반복적으로 여는 핵심 경험인 홈/피드/캘린더/통계에 집중된다.

## 8. 주요 화면 상세 기획

### 온보딩 화면

- 화면 목적: 응원팀과 기본 시즌 기준을 설정해 첫 기록까지 연결한다.
- 사용자 플로우: 앱 소개 → 응원팀 선택 → 알림/사진 권한 안내 → 홈 진입.
- 표시할 정보: 앱 한 줄 가치, 팀 선택 리스트, 데이터는 기기에 저장된다는 안내.
- 주요 UI 컴포넌트: 팀 컬러 그리드, 시작 버튼, 건너뛰기.
- CTA 버튼: `내 응원팀 선택하기`, `바로 시작`.
- 빈 상태: 팀 미선택 시 중립 사용자로 진행 가능.
- 에러 상태: seed 데이터 로드 실패 시 기본 팀 목록 재시도.
- 데이터 많아졌을 때: 해당 없음.
- MVP 구현 범위: 응원팀 선택만 포함.
- 개선: 온보딩 예시 대시보드, 기존 기록 가져오기.

### 홈 대시보드

- 화면 목적: 앱을 열자마자 내 직관 현황과 다음 행동을 보여준다.
- 사용자 플로우: 홈 진입 → 이번 시즌 요약 확인 → 빠른 등록 또는 최근 직관 상세 → 프로필/설정 진입.
- 표시할 정보: 이번 시즌 직관 수, 승/패/무/취소, 시즌 승률, 승리요정 지수, 최근 직관 카드, 최다 구장, 최근 다이어리 작성 상태.
- 주요 UI 컴포넌트: scoreboard hero, 요약 카드, 지수 배지, 최근 경기 미니 피드, 다이어리 완성 CTA, 플로팅 추가 버튼, 우측 상단 프로필/설정 아이콘.
- CTA 버튼: `직관 기록 추가`.
- 빈 상태: "첫 직관을 기록하면 승리요정 지수가 시작돼요."
- 에러 상태: 로컬 DB 조회 실패 시 재시도/진단 메시지.
- 데이터 많아졌을 때: 홈은 최근/요약만 보여주고 상세는 통계 탭으로 이동.
- MVP 구현 범위: 기본 요약, 최근 5경기, 빠른 기록 추가, 프로필/설정 진입. 최근 경기 중 다이어리가 비어 있으면 "지난 직관 후기를 완성해볼까요?" 같은 낮은 강도의 CTA를 노출할 수 있다.
- 개선: 시즌 목표, 공유 이미지, 다음 경기 후보, AI 후기 초안 진입. 과한 알림이나 압박형 문구는 피한다.

### 직관 로그 등록 화면

- 화면 목적: 최소 입력으로 경기 기록을 생성한다.
- 사용자 플로우: 날짜 선택 → 팀/상대/구장 선택 → 결과/점수 입력 → 한 줄 메모/다이어리 작성 → 저장.
- 표시할 정보: 필수 입력 진행 상태, 선택 입력 섹션, 한 줄 메모, 직관 다이어리 본문.
- 주요 UI 컴포넌트: 날짜 피커, 팀 선택 칩, 구장 선택 리스트, 결과 segmented control, 점수 stepper, 한 줄 메모 text field, 다이어리 text editor.
- CTA 버튼: `저장`, `상세 추가`, MVP 1.5차 `문장 자동 채우기`, v1.1 이후 `AI로 후기 초안 만들기`.
- 빈 상태: 최근 입력값 또는 응원팀 기본값 제안.
- 에러 상태: 필수값 누락, 같은 경기 중복 가능성 경고.
- 데이터 많아졌을 때: 최근 사용 구장/상대팀 우선 정렬.
- MVP 구현 범위: 날짜, 팀, 상대, 구장, 결과, 점수, 한 줄 메모, 수동 다이어리 입력.
- 개선: 사진, 태그, 좌석, 동행자, 후보 경기 추천, 템플릿 기반 자동 문장, 서버 기반 AI 초안.
- AI 보조 흐름: AI 버튼은 날짜/팀/구장/결과 등 필수 경기 정보가 어느 정도 입력된 뒤 활성화한다. 생성 결과는 bottom sheet 또는 preview card로 보여주고, 사용자가 `적용하기`를 눌렀을 때만 다이어리 본문에 반영한다.

### 피드 화면

- 화면 목적: 직관 기록을 단순 로그 리스트가 아니라 Instagram-like 세로 피드로 감상하게 한다. SNS를 복제하지 않고, 개인 시즌 다이어리의 시각적 완성도를 높이는 데 집중한다.
- 화면 이름: `FeedView`.
- 사용자 플로우: 피드 진입 → 시즌/결과 필터 → AttendancePostCard 스크롤 → 상세 진입 또는 공유 preview.
- 상단 타이틀: `직관 피드`.
- 표시할 정보: 날짜, 팀 매치업, 점수/결과, 구장, 사진 또는 구장/스코어보드형 header, 다이어리 캡션, 태그, 자세히 보기, 공유 placeholder.
- 주요 UI 컴포넌트: 시즌 필터, 결과 필터, `AttendancePostCard` 리스트, 빈 상태, 플로팅 추가 버튼.
- CTA 버튼: `+`, `자세히 보기`, `공유 카드 미리보기`.
- 빈 상태: "첫 직관을 피드에 남겨보세요."
- 에러 상태: 로드 실패, 사진 썸네일 실패, 삭제 실패.
- 데이터 많아졌을 때: LazyVStack, 월/시즌 anchor, 검색, 이미지 썸네일 캐싱.
- MVP 구현 범위: 최근순 피드 카드, 시즌 필터, 결과 필터, 상세 진입.
- 개선: 사진 carousel, 공유 카드, 친구 피드, 공개/비공개 설정.

### AttendancePostCard

- 화면 목적: 직관 기록 하나를 하나의 post처럼 보여주는 핵심 카드다.
- 화면 이름: `AttendancePostCard`.
- 구성:
  - 사진이 있으면 대표 사진 header를 노출한다.
  - 사진이 없으면 구장명, 팀 매치업, 점수를 활용한 scoreboard hero header를 노출한다.
  - 날짜, 시즌, 구장, 팀 매치업, 점수/결과 배지를 한눈에 읽히게 배치한다.
  - `captionText` 또는 `shortMemo`를 카드 본문 첫 줄로 보여준다.
  - `diaryText`가 있으면 일부 미리보기와 `자세히 보기`를 제공한다.
  - 태그는 1~3개 우선 노출하고 초과 개수를 표시한다.
  - 공유 기능은 MVP에서는 placeholder 또는 preview 진입만 제공한다.
- 상태: withPhoto, noPhotoScoreboard, win/loss/draw/canceled, diaryMissing, tagEmpty.
- 하이파이 기준: 카드가 와이어프레임처럼 보이지 않도록 실제 사진 영역, 스코어보드형 타이포, 결과 컬러, 티켓/post card 질감, 명확한 여백과 hierarchy를 가진다.

### 직관 로그 상세 화면

- 화면 목적: 한 경기의 기억과 데이터를 확인/수정한다.
- 사용자 플로우: 상세 확인 → 수정 → 삭제 또는 공유.
- 표시할 정보: 날짜, 팀, 구장, 결과, 점수, 좌석, 동행자, 한 줄 메모, 다이어리 본문, 사진, 태그.
- 주요 UI 컴포넌트: 경기 헤더, 결과 배지, 메모 카드, 다이어리 본문 영역, AI 생성 여부 배지(optional), 사진 그리드.
- CTA 버튼: `수정`, `삭제`.
- 빈 상태: 선택 입력값이 없으면 섹션 숨김.
- 에러 상태: 삭제 확인, 사진 로드 실패.
- 데이터 많아졌을 때: 사진은 썸네일 lazy 로드.
- MVP 구현 범위: 텍스트/정형 데이터 상세와 수정.
- 개선: 공유 이미지 생성, 관련 통계 연결, AI `다시 다듬기`. 공유 전에는 사용자가 문구를 수정할 수 있어야 하며, AI 생성 문구도 사용자 검토 후 공유한다.

### 통계 화면

- 화면 목적: 내 직관 데이터를 여러 축으로 분석한다.
- 사용자 플로우: 전체 요약 → 시즌/구장/상대팀 섹션 → 상세.
- 표시할 정보: 승률, 경기 수, 평균 득실점, 연승/연패, 순위형 통계.
- 주요 UI 컴포넌트: metric card, bar chart, result strip, filter chip.
- CTA 버튼: `시즌 선택`, `자세히 보기`.
- 빈 상태: 최소 1경기 필요, 승률 통계는 승/패 기록 1개 이상 필요.
- 에러 상태: 계산 실패 시 원본 로그 재조회.
- 데이터 많아졌을 때: 통계 계산 service 캐싱.
- MVP 구현 범위: 전체/시즌/구장/상대팀.
- 개선: 요일/월/좌석/동행자 분석.

### 구장별 통계 화면

- 화면 목적: 구장별 방문 횟수와 성적을 비교한다.
- 사용자 플로우: 구장 리스트 → 구장 상세 → 해당 로그 목록.
- 표시할 정보: 구장명, 홈팀, 방문 수, 승률, 최근 결과.
- 주요 UI 컴포넌트: 구장 순위 리스트, 승률 막대, 로그 링크.
- CTA 버튼: `이 구장 기록 보기`.
- 빈 상태: 구장 기록 없음.
- 에러 상태: 구장 seed 누락.
- 데이터 많아졌을 때: 방문 많은 구장 우선 정렬.
- MVP 구현 범위: 구장별 count/winRate.
- 개선: 지도, 구장 메모, 도장깨기.

### 시즌별 통계 화면

- 화면 목적: 연도/시즌 단위로 내 직관 성적을 비교한다.
- 사용자 플로우: 시즌 선택 → 시즌 요약 → 로그 목록.
- 표시할 정보: 시즌 직관 수, 승패무취소, 승률, 최다 구장/상대.
- 주요 UI 컴포넌트: 시즌 picker, 요약 카드, 월별 차트.
- CTA 버튼: `시즌 로그 보기`.
- 빈 상태: 해당 시즌 기록 없음.
- 에러 상태: 날짜 파싱 오류.
- 데이터 많아졌을 때: 시즌별 캐시.
- MVP 구현 범위: 연도 기준 시즌.
- 개선: 정규시즌/포스트시즌 구분.

### 캘린더 화면

- 화면 목적: 날짜 기반으로 직관 시즌을 회고한다. 캘린더는 보조 보기이 아니라 하단 핵심 탭이다.
- 화면 이름: `CalendarView`.
- 사용자 플로우: 월 선택/이동 → 월별 캘린더 그리드 확인 → 기록 있는 날짜 선택 → 날짜별 경기 bottom sheet → 상세 진입 또는 해당 날짜 기록 추가.
- 표시할 정보: 월 선택, 월별 캘린더 그리드, 직관한 날짜 result dot, 승/패/무/취소 색상, 해당 날짜 경기 수, 더블헤더/복수 경기 표시.
- 주요 UI 컴포넌트: `CalendarMonthView`, `CalendarDayCell`, `CalendarResultDot`, `CalendarDayDetailBottomSheet`.
- CTA 버튼: `이 날짜 기록 추가`.
- 빈 상태: 해당 월 기록 없음. 단, 빈 월도 캘린더 그리드는 유지하고 "이번 달 첫 직관을 남겨보세요." 같은 낮은 강도 CTA를 노출한다.
- 에러 상태: 날짜 중복 로그 표시 실패.
- 데이터 많아졌을 때: 월 단위 fetch.
- MVP 구현 범위: 최소 month view, result dot, 날짜 선택, 기록 추가 진입.
- 개선: 더블헤더/복수 경기 배지, 시즌 히트맵, 구장별 dot variation.

### CalendarDayDetailBottomSheet

- 화면 목적: 선택한 날짜의 경기 기록을 빠르게 확인하고 추가/상세로 연결한다.
- 화면 이름: `CalendarDayDetailBottomSheet`.
- 표시할 정보: 선택 날짜, 해당 날짜 직관 경기 카드, 팀 매치업, 결과, 점수, 구장, 다이어리 캡션 일부.
- CTA 버튼: `이 날짜에 기록 추가`, `자세히 보기`.
- 더블헤더/복수 경기 고려: 동일 날짜에 여러 로그가 있으면 카드 리스트로 표시하고, 경기 순서는 `date asc`, `createdAt asc` 또는 향후 `gameSequence`로 정렬한다.
- 빈 상태: 선택한 날짜에 기록이 없으면 `이 날짜에 기록 추가` CTA를 중심으로 보여준다.

### ShareCardPreview

- 화면 목적: 기록을 실제 SNS 공유 이미지로 만들기 전, 카드 포맷과 카피를 미리 확인한다.
- 화면 이름: `ShareCardPreview`.
- 표시할 정보: 대표 사진 또는 scoreboard hero, 날짜, 매치업, 점수, 결과, 구장, 승리요정 지수/시즌 요약 일부, 공유용 짧은 문구.
- CTA 버튼: MVP 1.5에서는 `미리보기`, v1.1 이후 `이미지 저장`, `공유하기`.
- MVP 구현 범위: 실제 공유 저장 없이 preview UI와 데이터 매핑만 준비할 수 있다.
- 개선: SNS 스토리 비율, 정사각형 피드 비율, 시즌 리포트 카드.

### 프로필/설정 화면

- 화면 목적: 개인화와 데이터 관리를 제공한다.
- 화면 이름: `ProfileSettingsView`.
- 사용자 플로우: 응원팀 변경 → 데이터 관리 → 앱 정보 확인.
- 표시할 정보: 응원팀, 총 기록 수, 저장 위치, 버전, 출처/주의사항, AI 개인정보 안내.
- 주요 UI 컴포넌트: setting row, team picker, export button.
- CTA 버튼: `응원팀 변경`, `데이터 내보내기`.
- 빈 상태: 응원팀 미설정.
- 에러 상태: export 실패.
- 데이터 많아졌을 때: 백업/내보내기 진행 상태 표시.
- MVP 구현 범위: 응원팀 변경, 앱 정보.
- 개선: iCloud 백업, CSV export/import.

## 9. 직관 로그 등록 UX

### 최소 입력으로 기록하기

MVP 필수 입력은 `날짜`, `응원팀`, `상대팀`, `구장`, `결과`로 제한한다. 점수는 권장 입력으로 두되 결과가 취소이면 비활성화한다. 한 줄 메모와 직관 다이어리는 기본 입력 영역으로 제공하되 비워도 저장 가능하게 한다. 좌석, 사진, 태그, 동행자는 선택 입력이다.

### 상세 입력은 나중에 추가 가능하게 하기

등록 화면은 기본 섹션과 상세 섹션을 나눈다. 저장 후 상세 화면에서 언제든 수정할 수 있게 하며, 피드 카드에는 필수 데이터만 있어도 사진 없는 scoreboard hero로 자연스럽게 표시되도록 한다.

### 필수 입력값과 선택 입력값

- 필수: 날짜, 응원팀, 상대팀, 구장, 결과
- 권장: 우리 팀 점수, 상대 점수
- 선택: 한 줄 메모, 직관 다이어리, 좌석, 동행자, 사진, 태그, 선발투수 메모, 날씨

### 날짜/팀/구장 선택 UX

- 날짜: 기본값 오늘, 과거 날짜 선택 쉬운 calendar/date picker.
- 응원팀: 온보딩에서 선택한 팀을 기본값으로 자동 세팅.
- 상대팀: 응원팀 제외 9개 팀 우선 표시, 검색 가능.
- 구장: 응원팀 홈구장 또는 상대팀 홈구장을 추천하되 사용자가 변경 가능.
- 중립/제2구장: `중립 경기`, `기타 구장` 선택 제공.

### 점수 입력 UX

Stepper와 숫자 입력을 함께 제공한다. 결과와 점수의 논리 불일치가 있으면 저장 전 경고한다. 예: 결과가 승인데 우리 팀 점수가 낮으면 "점수와 결과가 맞지 않는 것 같아요"를 표시하되 강제 차단하지 않는다.

### 사진 첨부 UX

MVP 1.5차로 둔다. `PhotosPicker`를 사용하고, 원본 저장 대신 앱 전용 디렉터리에 압축 썸네일/표준 이미지를 저장한다. 사진 권한 거부 시 텍스트 기록은 계속 가능해야 한다.

### 태그 입력 UX

초기 추천 태그: `역전승`, `끝내기`, `연장`, `우천`, `원정`, `시리즈`, `첫 직관`, `포스트시즌`, `매진`. 사용자 커스텀 태그는 확장 단계에서 추가한다.

### 자동 저장 또는 임시 저장

등록 중 이탈 가능성이 있으므로 MVP에서는 화면 dismiss 전에 확인 alert를 띄운다. 1.5차에서는 draft 저장을 고려한다.

### 경기 결과를 모를 때 처리

`결과 미정` 상태를 별도로 둘 수 있지만 MVP 통계가 복잡해진다. 초기에는 결과 필수를 권장하고, 경기 중 기록을 위해 1.5차에서 `진행/미정`을 추가한다.

### 경기 취소/우천 취소 처리

결과 enum에 `canceled`를 포함한다. 취소 경기는 직관 시도/방문 횟수에는 포함할지 설정이 필요하다. MVP 기본 정책은 "직관 로그 수에는 포함, 승률/평균 득실점에서는 제외"다.

### 같은 날 여러 경기/더블헤더

동일 날짜, 동일 팀, 동일 구장이 있어도 저장 가능하게 한다. 중복 가능성 경고만 띄운다. 더블헤더 구분을 위해 `gameSequence` 또는 `memo`를 나중에 추가할 수 있다.

### KBO 팀/구장 데이터 기본 제공 방식

앱 번들에 JSON seed로 제공한다. 팀명/연고지/홈구장/팀컬러/활성 여부를 포함하고, 변경 이력 대응을 위해 `validFrom`, `validTo`, `previousNames` 필드를 고려한다.

### AI 보조 다이어리 작성 UX

- 사용자는 긴 글을 처음부터 쓰지 않아도 된다. 수동 한 줄 메모와 다이어리 입력은 항상 기본 경로로 유지한다.
- 사용자가 선택하는 입력값: 오늘의 분위기, 경기 하이라이트, 동행 유형, 말투, 추가로 꼭 넣고 싶은 문장.
- AI가 생성하는 값: 한 줄 요약, 직관 다이어리 본문, SNS 공유용 문구, 해시태그 후보.
- AI 결과는 초안이다. 사용자가 preview에서 수정하거나 `적용하기`를 눌러야 최종 저장 대상이 된다.
- AI 작성 버튼은 선택 기능이며, 수동 작성 경험을 방해하지 않는다.
- 네트워크 실패, 서버 장애, 사용량 제한 초과 시 수동 작성과 템플릿 기반 문장 생성으로 graceful fallback 한다.
- AI 생성 결과에는 부정확한 정보가 포함될 수 있음을 "초안은 저장 전 꼭 확인해 주세요"처럼 부드럽게 안내한다.
- 사진 원본, 정확한 위치, 동행자 실명, 민감한 메모 원문은 기본적으로 AI 요청 payload에서 제외한다.

## 10. 데이터 모델

### 로컬 저장 방식 비교

| 방식 | 장점 | 단점 | 추천 |
|---|---|---|---|
| SwiftData | SwiftUI와 잘 맞고 선언적 모델 작성이 쉬움, MVP 속도 좋음 | OS 버전 제약, 복잡한 마이그레이션은 주의 | iOS 17+ 타깃이면 1순위 |
| CoreData | 성숙하고 강력함, iCloud 연계 경험 많음 | 보일러플레이트와 학습 부담 | iOS 16 이하 지원 필요 시 |
| SQLite 직접 사용 | 이식성/쿼리 통제력 좋음 | ORM/마이그레이션 직접 관리 | 통계 쿼리가 매우 복잡해질 때 |

MVP 추천: iOS 17 이상을 기본 타깃으로 둘 수 있다면 SwiftData를 사용한다. 단, 통계 계산은 저장소에 과도하게 묶지 말고 `StatisticsService`에서 순수 Swift 로직으로 계산해 테스트 가능하게 둔다.

### 모델 설계

| 모델명 | 역할 | 주요 필드/타입 | 필수 | 예시 | 관계 | 인덱싱/정렬 | MVP |
|---|---|---|---|---|---|---|---|
| UserProfile | 사용자 기본 설정 | id UUID, favoriteTeamID String?, createdAt Date | 일부 | LG | Team 참조 | createdAt | 필요 |
| Team | KBO 팀 seed | id String, name String, shortName String, city String, homeStadiumID String, primaryColorHex String, active Bool | 예 | `lg-twins` | Stadium | name | 필요 |
| Stadium | 구장 seed | id String, name String, city String, address String?, homeTeamIDs [String], active Bool | 예 | `jamsil` | Team 다대다 | name/city | 필요 |
| AttendanceLog | 직관 로그 핵심 | id UUID, date Date, season Int, favoriteTeamID String, opponentTeamID String, stadiumID String, result GameResult, ourScore Int?, opponentScore Int?, seatText String?, companionText String?, shortMemo String?, captionText String?, diaryText String?, photoLocalPaths [String], tagNames [String], feedVisibility FeedVisibility 또는 isShareable Bool, calendarDisplayResult GameResult?, createdAt Date, updatedAt Date | 핵심 필드 예 | 2026-04-01 LG vs KIA | photos/tags/diary | date desc, season | 필요 |
| GameResult | 결과 enum | win, loss, draw, canceled | 예 | win | AttendanceLog | result | 필요 |
| FeedVisibility | 피드/공유 노출 정책 enum | privateOnly, shareable | 아니오 | privateOnly | AttendanceLog | visibility | 1.5 |
| DiaryWritingTone | 다이어리 말투 enum | plain, emotional, playful, socialCaption | 아니오 | emotional | AttendanceLog | tone | 1.5 |
| LogPhoto | 사진 | id UUID, logID UUID, localPath String, createdAt Date | 예 | image path | AttendanceLog | createdAt | 1.5 |
| LogTag | 태그 | id UUID, name String, colorHex String? | 예 | 끝내기 | AttendanceLog 다대다 | name | 1.5 |
| Companion | 동행자 | id UUID, name String, note String? | 아니오 | 민수 | AttendanceLog 다대다 | name | 확장 |
| SeasonStats | 계산 결과 DTO | season Int, total Int, wins Int, losses Int, draws Int, canceled Int, winRate Double? | 계산 | 2026 | 로그 기반 | season | 필요 |
| StadiumStats | 계산 결과 DTO | stadiumID String, total Int, winRate Double? | 계산 | 잠실 5경기 | 로그 기반 | total desc | 필요 |
| TeamMatchupStats | 계산 결과 DTO | opponentTeamID String, total Int, winRate Double? | 계산 | vs KIA | 로그 기반 | total desc | 필요 |

### AI/다이어리 확장 필드 정책

- `shortMemo`: 카드와 상세 화면에 노출되는 사용자의 짧은 메모다.
- `captionText`: 피드 카드에서 Instagram-like caption처럼 우선 노출되는 짧은 문장이다. 없으면 `shortMemo`를 대체 표시한다.
- `diaryText`: 사용자가 직접 작성하거나 AI/템플릿 초안을 적용한 뒤 수정한 최종 다이어리 본문이다.
- `photoLocalPaths`: 앱 전용 디렉터리에 저장된 사진 경로 배열이다. MVP 1차에서는 빈 배열로 시작할 수 있다.
- `tagNames`: 특이 경기, 분위기, 원정, 포스트시즌 등 피드/통계에 재사용할 태그명 배열이다.
- `feedVisibility` 또는 `isShareable`: MVP는 로컬 개인 기록이 기본이므로 `privateOnly`가 기본값이다. 공유 카드나 친구 피드 확장 시 사용한다.
- `calendarDisplayResult`: 캘린더 dot에 표시할 결과다. 기본은 `result`와 같지만, 취소/더블헤더/미정 같은 예외 표현을 분리할 수 있다.
- `aiGeneratedSummary`, `aiGeneratedShareText`, `aiGeneratedHashtags`: 사용자가 적용한 AI 초안의 보조 결과를 저장할 수 있다. 서버 응답 원문 전체가 아니라 화면에 필요한 필드만 저장한다.
- `aiDraftApplied`: AI 또는 템플릿 초안이 본문에 적용된 적이 있는지 표시한다. 최종 본문은 사용자 편집본으로 취급한다.
- `aiGeneratedAt`: AI 초안 생성 시각이다. 템플릿 생성에는 비워둘 수 있다.
- `moodTags`, `highlightTags`, `writingTone`: 로컬 템플릿 생성과 서버 기반 AI 요청에 재사용 가능한 구조화 입력값이다.
- `diaryUpdatedAt`: 다이어리 본문이 마지막으로 수정된 시각이다.
- AI 요청에 사용한 원본 프롬프트 전체를 로컬에 저장하는 것은 추천하지 않는다. 저장이 필요하다면 디버그 빌드 한정 또는 사용자 명시 동의 기반으로 제한한다.
- 동행자 실명, 상세 위치, 사진 원본 분석 결과는 기본적으로 AI 요청 payload에서 제외한다.

### SwiftData 예시

```swift
import Foundation
import SwiftData

enum GameResult: String, Codable, CaseIterable {
    case win
    case loss
    case draw
    case canceled
}

enum DiaryWritingTone: String, Codable, CaseIterable {
    case plain
    case emotional
    case playful
    case socialCaption
}

enum FeedVisibility: String, Codable, CaseIterable {
    case privateOnly
    case shareable
}

@Model
final class AttendanceLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var season: Int
    var favoriteTeamID: String
    var opponentTeamID: String
    var stadiumID: String
    var resultRawValue: String
    var ourScore: Int?
    var opponentScore: Int?
    var seatText: String?
    var companionText: String?
    var shortMemo: String?
    var captionText: String?
    var diaryText: String?
    var photoLocalPaths: [String]
    var tagNames: [String]
    var feedVisibilityRawValue: String
    var calendarDisplayResultRawValue: String?
    var aiGeneratedSummary: String?
    var aiGeneratedShareText: String?
    var aiGeneratedHashtags: [String]
    var aiDraftApplied: Bool
    var aiGeneratedAt: Date?
    var moodTags: [String]
    var highlightTags: [String]
    var writingToneRawValue: String?
    var diaryUpdatedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var result: GameResult {
        get { GameResult(rawValue: resultRawValue) ?? .canceled }
        set { resultRawValue = newValue.rawValue }
    }

    var feedVisibility: FeedVisibility {
        get { FeedVisibility(rawValue: feedVisibilityRawValue) ?? .privateOnly }
        set { feedVisibilityRawValue = newValue.rawValue }
    }

    var calendarDisplayResult: GameResult {
        get { calendarDisplayResultRawValue.flatMap(GameResult.init(rawValue:)) ?? result }
        set { calendarDisplayResultRawValue = newValue.rawValue }
    }

    var writingTone: DiaryWritingTone? {
        get { writingToneRawValue.flatMap(DiaryWritingTone.init(rawValue:)) }
        set { writingToneRawValue = newValue?.rawValue }
    }

    init(date: Date, season: Int, favoriteTeamID: String, opponentTeamID: String, stadiumID: String, result: GameResult) {
        self.id = UUID()
        self.date = date
        self.season = season
        self.favoriteTeamID = favoriteTeamID
        self.opponentTeamID = opponentTeamID
        self.stadiumID = stadiumID
        self.resultRawValue = result.rawValue
        self.photoLocalPaths = []
        self.tagNames = []
        self.feedVisibilityRawValue = FeedVisibility.privateOnly.rawValue
        self.aiGeneratedHashtags = []
        self.aiDraftApplied = false
        self.moodTags = []
        self.highlightTags = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

## 11. 통계 계산 로직

### 기본 정책

- 승률 분모는 `승 + 패`만 사용한다.
- 무승부는 별도 카운트하고 승률 계산에서 제외한다.
- 취소는 방문/기록 수에는 표시할 수 있으나 승률, 평균 득점, 평균 실점에서는 제외한다.
- 점수 미입력 경기는 평균 득실점 계산에서 제외한다.
- 날짜순 계산은 `date asc`, 동일 날짜는 `createdAt asc`를 사용한다.

| 통계명 | 설명 | 계산식 | 제외 데이터 | 무/취소 처리 | 표시 | MVP |
|---|---|---|---|---|---|---|
| 전체 직관 횟수 | 등록 로그 수 | count(logs) | 없음 | 포함 | `총 12경기` | 포함 |
| 전체 승/패/무/취소 | 결과별 수 | group by result | 없음 | 각각 표시 | `7승 4패 1무` | 포함 |
| 전체 직관 승률 | 전체 승패 기준 | wins / (wins + losses) | draw, canceled | 제외 | `%` | 포함 |
| 시즌별 직관 승률 | 시즌별 승률 | season group 후 동일 | draw, canceled | 제외 | 시즌 카드 | 포함 |
| 구장별 승률 | 구장별 성적 | stadium group | draw, canceled | 제외 | 순위/막대 | 포함 |
| 상대팀별 승률 | 상대별 성적 | opponent group | draw, canceled | 제외 | 리스트 | 포함 |
| 요일별 승률 | 요일 패턴 | weekday group | draw, canceled | 제외 | 요일 막대 | 1.5 |
| 월별 직관 횟수 | 월별 방문량 | yearMonth group count | 없음 | 포함 | calendar/bar | 1.5 |
| 평균 득점 | 우리 팀 평균 득점 | sum(ourScore)/count(scoreFilled) | canceled, nil score | draw는 포함 가능 | `평균 4.8득점` | 포함 |
| 평균 실점 | 상대 평균 득점 | sum(opponentScore)/count(scoreFilled) | canceled, nil score | draw는 포함 가능 | `평균 3.9실점` | 포함 |
| 최다 직관 구장 | 가장 많이 간 구장 | max count by stadium | 없음 | 포함 | `잠실 8회` | 포함 |
| 최다 상대팀 | 가장 많이 본 상대 | max count by opponent | 없음 | 포함 | `vs KIA 5회` | 포함 |
| 연승/연패 | 연속 승패 흐름 | 날짜순 win/loss streak | draw, canceled는 streak 중단 또는 무시 정책 | MVP는 중단 | `현재 3연승` | 포함 |
| 최근 5경기 결과 | 최근 흐름 | date desc limit 5 | 없음 | 그대로 표시 | W-L-D-C strip | 포함 |
| 내가 가면 이기는 팀/지는 팀 | 상대별 승률 최고/최저 | opponent group, min sample 적용 | 표본 미달 제외 | draw/cancel 제외 | `상대별 궁합` | 확장 |
| 승리요정 지수 | 재미용 보정 점수 | 12장 참조 | 표본 미달 별도 | draw/cancel 제외 | 지수/등급 | 포함 |

## 12. 승리요정 지수

### 지수 이름 후보

- 승리요정 지수
- 직관 행운 지수
- 승요력
- Fairy Score
- Lucky Charm Index

### 계산 방식 후보

1. 단순 승률 방식: `승 / (승 + 패) * 100`
   - 쉽지만 표본이 적으면 과장된다.
2. 표본 보정 승률 방식: `((승 + 기준승률 * 보정경기수) / (승 + 패 + 보정경기수)) * 100`
   - 추천. 예: 기준승률 0.5, 보정경기수 6.
3. 최근 흐름 가중 방식: 전체 보정 승률 70% + 최근 5경기 승률 30%.
   - 재미는 있으나 초반 변동이 크다.
4. 기대 대비 방식: 응원팀 시즌 실제 승률 대비 내 직관 승률 차이.
   - 가장 야구 데이터답지만 공식 시즌 승률 데이터 연동이 필요하다.

### 추천 계산 방식

MVP는 표본 보정 승률 방식을 추천한다.

```text
승리요정 지수 = ((승 + 0.5 * 6) / (승 + 패 + 6)) * 100
```

이 방식은 1승 0패 사용자가 바로 100점이 되는 문제를 줄인다. 10경기 이상부터 사용자의 실제 승률에 더 가까워진다.

### 표현 방식과 등급

| 조건 | 등급 | 문구 |
|---|---|---|
| 승+패 0~2경기 | 표본 수집 중 | 아직 요정력을 판단하기엔 이른 시즌이에요 |
| 지수 70+ | 전설의 승리요정 | 직관석에 승리 기운이 강합니다 |
| 지수 60~69 | 승리 기운 있음 | 꽤 좋은 흐름이에요 |
| 지수 50~59 | 평균 이상의 행운 | 좋은 날이 조금 더 많아요 |
| 지수 40~49 | 균형의 팬 | 승패를 함께 견디는 진짜 팬 |
| 지수 < 40 | 반등 대기 중 | 다음 직관에서 흐름을 바꿔봐요 |

### 처리 정책

- 표본 수가 적을 때: 점수보다 `표본 수집 중` 상태를 우선 표시.
- 무승부: 승률 분자/분모에서 제외하되 별도 "무승부 경험"으로 표시.
- 취소: 지수 계산 제외.
- 시즌별/전체 구분: 홈에는 현재 시즌 지수를 기본으로 보여주고, 통계 화면에서 전체 지수를 제공.
- 홈 표시: 원형 게이지보다 작고 단단한 metric card 추천. 예: `승리요정 지수 63 · 승리 기운 있음`.
- 공유 이미지: 시즌 종료 또는 10경기 달성 시 `나의 2026 직관 성적` 카드로 확장 가능.

## 13. AI 직관 다이어리 보조 기능

### 기능 개요

AI 직관 다이어리 보조 기능은 직관 로그에 입력된 경기 정보와 사용자가 선택한 감정/분위기/하이라이트를 바탕으로 다이어리 초안을 생성한다. 사용자는 초안을 그대로 저장하지 않고, 반드시 preview에서 확인하고 수정한 뒤 저장한다.

AI는 기록을 대신 작성하는 기능이 아니라 기록을 시작하기 쉽게 만드는 도구다. 사용자가 작성한 직관 기록과 기억이 주인공이며, AI는 표현을 정리하고 초안을 제안하는 보조 역할에 머문다.

### 사용자 입력값

- 날짜
- 응원팀
- 상대팀
- 구장
- 결과
- 점수
- 분위기
- 하이라이트
- 동행 유형
- 말투
- 추가 메모

### AI 생성 결과

- 한 줄 요약
- 직관 다이어리 본문
- SNS 공유용 문구
- 해시태그 후보

### UX 플로우

1. 사용자가 직관 로그 기본 정보를 입력한다.
2. 분위기/하이라이트/말투를 선택한다.
3. `AI로 후기 초안 만들기` 버튼을 누른다.
4. 앱은 민감 정보를 제외한 최소 payload만 서버에 전달한다.
5. 서버는 LLM을 호출해 초안을 생성한다.
6. 앱은 preview card 또는 bottom sheet로 결과를 보여준다.
7. 사용자가 수정/적용/다시 생성/취소 중 하나를 선택한다.
8. 사용자가 저장해야만 최종 로그에 반영된다.

### 템플릿 기반 fallback

LLM 서버가 없거나 요청이 실패해도 기본 문장 생성이 가능해야 한다. MVP 1.5차에서는 외부 API 없이 `DiaryTemplateGenerator`가 로컬 문자열 조합으로 다음 수준의 문장을 만든다.

```text
오늘은 {구장}에서 {응원팀} 경기를 직관했다. 결과는 {우리점수}:{상대점수} {결과}.
{하이라이트} 덕분에 더 기억에 남는 경기였다.
```

템플릿 기반 생성은 비용과 개인정보 전송이 없고, 수동 작성 UX를 방해하지 않는다.

### 말투 옵션

- 담백하게
- 감성적으로
- 유쾌하게
- SNS 캡션처럼

### 예시 결과

예시 1:

```text
한 줄 요약: 잠실에서 짜릿한 역전승을 본 날.
본문: 오늘은 잠실야구장에서 LG 경기를 직관했다. 초반에는 조금 답답했지만, 후반 역전 장면이 나오면서 응원석 분위기가 완전히 달라졌다. 마지막 아웃카운트가 올라갈 때까지 긴장했지만, 결국 웃으면서 집에 갈 수 있었던 경기였다.
SNS 문구: 역시 직관은 이런 맛. 잠실 역전승 완료.
해시태그: #승리요정 #KBO직관 #잠실야구장 #역전승
```

예시 2:

```text
한 줄 요약: 아쉬웠지만 오래 기억에 남을 우천 취소 직관.
본문: 오늘은 사직야구장에 갔지만 비 때문에 경기가 취소됐다. 결과는 남지 않았지만, 경기장에 도착해서 느낀 분위기와 함께 간 사람들과의 시간이 남았다. 다음 직관에서는 꼭 끝까지 경기를 보고 싶다.
SNS 문구: 비가 막은 직관, 다음엔 승리까지 보고 온다.
해시태그: #승리요정 #KBO직관 #우천취소 #사직야구장
```

## 14. AI 보안/프라이버시/비용 제어 설계

### 핵심 보안 원칙

- iOS 앱에 LLM API Key를 절대 포함하지 않는다.
- LLM 호출은 백엔드 서버를 통해서만 수행한다.
- 서버는 인증, 사용량 제한, 프롬프트 구성, 응답 검증, 비용 로깅을 담당한다.
- 앱은 최소한의 구조화된 입력값만 서버로 보낸다.
- 사용자가 작성한 원문 전체, 동행자 실명, 상세 위치, 사진 원본은 기본적으로 전송하지 않는다.
- 사용자의 명시적 동의 없이 AI 학습/분석 목적으로 기록을 재사용하지 않는다.

### 추천 아키텍처

```text
iOS App -> VictoryFairy API Server -> LLM Provider
```

iOS 책임:

- 로그인/익명 사용자 식별 또는 디바이스 단위 제한
- AI 요청 화면
- 입력값 최소화
- 결과 preview
- 사용자 수정/저장

서버 책임:

- API Key 보관
- 인증/권한 확인
- rate limit
- daily/monthly usage limit
- prompt template 관리
- payload validation
- LLM 호출
- 응답 JSON schema 검증
- moderation 또는 safety check
- 비용/토큰/latency logging
- abuse 방지

LLM Provider 책임:

- 초안 생성
- 구조화된 JSON 응답 반환

### API 설계 초안

엔드포인트:

```http
POST /api/v1/ai/diary-draft
```

Request 예시:

```json
{
  "gameDate": "2026-05-01",
  "favoriteTeamName": "LG 트윈스",
  "opponentTeamName": "KIA 타이거즈",
  "stadiumName": "잠실야구장",
  "result": "win",
  "score": {
    "favoriteTeam": 5,
    "opponentTeam": 3
  },
  "moodTags": ["짜릿함", "열광적"],
  "highlightTags": ["역전승", "응원 분위기"],
  "companionType": "friends",
  "tone": "playful",
  "extraNoteSanitized": "9회 응원 분위기가 가장 기억에 남았다.",
  "locale": "ko-KR"
}
```

Response 예시:

```json
{
  "summary": "잠실에서 짜릿한 역전승을 본 날.",
  "diaryText": "오늘은 잠실야구장에서 LG 경기를 직관했다...",
  "shareText": "역시 직관은 이런 맛. 잠실 역전승 완료.",
  "hashtags": ["#승리요정", "#KBO직관", "#잠실야구장", "#역전승"],
  "warnings": ["AI 초안은 부정확할 수 있으니 저장 전 확인해 주세요."]
}
```

요청/응답 예시에는 실제 API Key, 사용자 식별 토큰, 동행자 실명, 정확한 위치, 사진 데이터 같은 민감 정보를 포함하지 않는다.

### Payload 최소화 정책

- `companionText` 원문 대신 `companionType`만 전송한다. 예: alone, friends, family, partner, group.
- `seatText`는 기본 전송 제외한다.
- precise location 전송은 금지한다. 구장명만 사용한다.
- photo binary/base64 전송은 금지한다.
- 사용자의 전체 메모가 아니라 사용자가 선택한 `extraNoteSanitized`만 전송하고 길이를 제한한다.
- profanity/개인정보 필터링을 거친 뒤 서버로 보낸다.
- 요청 payload의 최대 길이와 배열 개수를 제한한다.
- 팀/구장/결과/점수처럼 이미 구조화된 값만 기본 전송한다.

### 저장/로그 정책

- 서버에는 원문 요청 payload를 장기 저장하지 않는다.
- 저장이 필요하다면 `userID`, `requestID`, `model`, `tokenUsage`, `latency`, `status`, `createdAt` 정도만 저장한다.
- 디버그 목적 payload 저장은 개발 환경에서만 허용하고, 운영에서는 비활성화한다.
- 사용자의 다이어리 본문은 기본적으로 로컬 저장 또는 사용자가 선택한 계정 저장소에만 저장한다.
- LLM 응답도 서버에서 장기 저장하지 않는다.
- 개인정보 처리방침에 AI 기능의 데이터 전송 범위, 보관 기간, 제3자 제공 여부를 명시한다.

### 비용 제어

- 무료 사용자 일일 또는 월간 생성 횟수를 제한한다.
- 한 로그당 재생성 횟수를 제한한다.
- 요청 길이와 추가 메모 길이를 제한한다.
- 저비용 모델을 우선 사용하고 고급 모델은 프리미엄 기능으로 분리할 수 있다.
- timeout을 짧게 설정하고 실패 시 template fallback으로 전환한다.
- 토큰 사용량, 요청 수, 실패율, latency를 로깅한다.
- 사용자/IP/device 단위 rate limit을 적용한다.
- abuse detection으로 반복 호출, 자동화 호출, 비정상 payload를 차단한다.
- 동일 입력에 대한 캐시 가능 여부를 검토하되, 개인정보와 사용자 기대를 해치지 않는 범위로 제한한다.

### 프롬프트 인젝션 방어

- 사용자의 `extraNote`는 시스템 프롬프트가 아니라 데이터 필드로만 취급한다.
- 서버는 고정 system prompt와 JSON schema를 사용한다.
- 모델 출력은 반드시 JSON schema로 검증한다.
- 앱은 검증된 필드만 렌더링한다.
- HTML/Markdown/링크 자동 실행을 금지한다.
- 욕설, 개인정보, 명예훼손성 결과는 필터링하거나 재생성 안내를 제공한다.
- 모델이 정책/시스템 지시를 노출하거나 API Key를 요구하는 출력은 실패로 처리한다.

### 사용자 고지/동의

- AI 초안 생성 전 "입력한 일부 정보가 AI 초안 생성을 위해 서버로 전송됩니다"라고 안내한다.
- 전송되는 항목 보기를 제공한다.
- 사진, 정확한 위치, 동행자 실명은 전송하지 않는다고 설명한다.
- AI 결과가 부정확할 수 있으므로 저장 전 확인이 필요하다고 안내한다.
- AI 기능 사용은 선택이며 수동 기록은 계속 가능하다.

### 장애 대응

| 상황 | 사용자 메시지 | fallback |
|---|---|---|
| LLM 요청 실패 | "AI 초안을 만들지 못했어요. 기본 문장으로 채워볼게요." | 템플릿 생성 |
| timeout | "응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요." | 수동 작성 유지 |
| rate limit 초과 | "오늘 사용할 수 있는 AI 초안 횟수를 모두 사용했어요." | 템플릿 생성 |
| 부적절한 결과 생성 | "초안이 적절하지 않아 다시 확인이 필요해요." | 재생성 또는 수동 작성 |
| 네트워크 없음 | "오프라인 상태라 AI 초안을 만들 수 없어요." | 로컬 템플릿 |
| 서버 점검 | "AI 기능이 잠시 점검 중이에요. 기록은 계속 저장할 수 있어요." | 수동 작성 유지 |

## 15. KBO 기본 데이터 설계

> 2026-05-01 기준 조사 결과를 바탕으로 한 기획용 초안이다. 팀명, 구장명, 감독, 구장 수용 인원, 제2구장 편성은 변동 가능성이 있으므로 구현 직전 KBO 공식 사이트와 각 구단 공식 사이트로 재확인한다.

### KBO 팀 목록 초안

| 팀명 | 연고지 | 홈구장 초안 | 팀 컬러 사용 가능성 |
|---|---|---|---|
| LG 트윈스 | 서울특별시 | 잠실야구장 | red/black 계열 |
| 두산 베어스 | 서울특별시 | 잠실야구장 | navy/white 계열 |
| 키움 히어로즈 | 서울특별시 | 고척스카이돔 | burgundy 계열 |
| SSG 랜더스 | 인천광역시 | 인천 SSG 랜더스필드 | red 계열 |
| KT 위즈 | 수원시 | 수원 kt wiz 파크 | black/red 계열 |
| 한화 이글스 | 대전광역시 | 대전 한화생명 볼파크 | orange/black 계열 |
| 삼성 라이온즈 | 대구광역시 | 대구 삼성 라이온즈 파크 | blue 계열 |
| KIA 타이거즈 | 광주광역시 | 광주-기아 챔피언스 필드 | red/navy 계열 |
| 롯데 자이언츠 | 부산광역시 | 사직야구장 | navy/red 계열 |
| NC 다이노스 | 창원시 | 창원NC파크 | navy/gold 계열 |

### 구장 목록 초안

| 구장 | 위치 | 관련 팀 | 메모 기능 가능성 |
|---|---|---|---|
| 잠실야구장 | 서울 송파구 | LG, 두산 | 공동 홈구장, 홈/원정 응원석 주의 |
| 고척스카이돔 | 서울 구로구 | 키움 | 돔구장, 우천 취소 가능성 낮음 |
| 인천 SSG 랜더스필드 | 인천 미추홀구 | SSG | 원정 기록 메모 |
| 수원 kt wiz 파크 | 경기 수원시 | KT | 원정/좌석 메모 |
| 대전 한화생명 볼파크 | 대전광역시 | 한화 | 신규 구장 정보 재확인 필요 |
| 대구 삼성 라이온즈 파크 | 대구 수성구 | 삼성 | 구장별 관람 경험 메모 |
| 광주-기아 챔피언스 필드 | 광주 북구 | KIA | 원정/응원석 메모 |
| 사직야구장 | 부산 동래구 | 롯데 | 원정/응원 문화 메모 |
| 창원NC파크 | 경남 창원시 | NC | 구장 방문 기록 |
| 기타/중립/제2구장 | 울산, 포항, 청주 등 | 시즌별 편성 | 직접 입력 또는 seed 확장 |

### 특이 케이스

- 잠실은 LG와 두산이 공동 사용한다. `homeTeamIDs`를 배열로 둔다.
- 중립 경기와 포스트시즌은 홈팀/구장 관계가 일반 경기와 다를 수 있다.
- 제2구장 편성은 시즌마다 달라질 수 있으므로 `Stadium.active`, `isSecondary`, `validFrom`, `validTo`를 둔다.
- 팀명 변경, 구장명 변경은 기존 로그 보존이 중요하다. 로그에는 teamID/stadiumID를 저장하고, 표시명은 seed 버전 또는 스냅샷을 고려한다.

## 16. iOS 구현 방향

### SwiftUI vs UIKit

MVP는 SwiftUI를 추천한다. 폼, 리스트, 탭, 차트, 상태 기반 UI 구현이 빠르고 개인/소규모 프로젝트에 적합하다. UIKit은 사진 처리, 복잡한 커스텀 캘린더, 레거시 호환이 필요할 때 부분적으로 사용할 수 있다.

### SwiftData vs CoreData

iOS 17 이상을 타깃으로 하면 SwiftData를 추천한다. 로컬 로그 앱의 CRUD와 SwiftUI 바인딩에 잘 맞는다. iOS 16 이하까지 지원해야 한다면 CoreData를 선택한다.

### 아키텍처

과도한 Clean Architecture는 피하고 `Feature-based MVVM + Repository + Service` 구조를 추천한다.

- View: SwiftUI 화면
- ViewModel: 화면 상태와 사용자 액션 처리
- Repository: SwiftData fetch/save/delete 추상화
- StatisticsService: 로그 배열을 받아 통계 DTO를 반환하는 순수 로직
- DiaryTemplateGenerator: MVP 1.5차에서 외부 API 없이 다이어리 문장 자동 채우기
- DiaryDraftService: 템플릿/AI 초안 생성을 ViewModel에 제공하는 추상화
- DiarySanitizer: AI 서버 전송 전 메모와 입력값에서 개인정보/과도한 길이를 제거
- SeedDataProvider: KBO 팀/구장 기본 데이터 제공
- DesignSystem: 색상, 타이포, 카드, 배지

### 확장 가능성

서버/동기화가 붙어도 ViewModel은 Repository 프로토콜에 의존하게 둔다. 나중에 `LocalAttendanceLogRepository`를 `SyncingAttendanceLogRepository`로 교체할 수 있다.

AI 기능도 같은 원칙을 따른다. MVP 1차에서는 `shortMemo`/`diaryText` 필드와 수동 입력만 구현한다. MVP 1.5차에서는 `DiaryTemplateGenerator`를 로컬 서비스로 추가한다. 서버 API가 준비된 뒤에만 `DiaryAIClient`를 구현하고, iOS 앱에는 LLM API Key를 `Info.plist`, `xcconfig`, source code, remote config 어디에도 넣지 않는다. iOS 설정에는 VictoryFairy API server endpoint만 둔다.

AI 확장 모듈:

- `DiaryDraftService`: ViewModel이 호출하는 초안 생성 인터페이스. 내부에서 템플릿 또는 서버 기반 AI를 선택한다.
- `DiaryTemplateGenerator`: 로컬 문자열 조합 기반 fallback. MVP 1.5차 구현 대상.
- `DiaryAIClient`: 서버의 `/api/v1/ai/diary-draft`를 호출한다. LLM provider와 직접 통신하지 않는다.
- `DiarySanitizer`: `extraNote`, mood/highlight/tone 입력을 정규화하고 payload 길이를 제한한다.
- `AIUsageLimitState`: 로컬 표시용 사용량 상태. 실제 제한 판정은 서버가 최종 책임진다.
- `DiaryDraftViewModel`: bottom sheet/preview card의 생성, 재생성, 적용, 취소 상태를 관리한다.

### DI 방식

초기에는 Environment 또는 앱 루트에서 repository/service를 생성해 주입한다. 복잡한 DI 컨테이너는 도입하지 않는다.

### 테스트 가능성

통계 계산은 SwiftData와 분리해 순수 함수로 테스트한다. ViewModel은 mock repository로 저장/수정/삭제 플로우를 검증한다.

AI 관련 테스트는 실제 LLM 호출 없이 진행한다. `DiaryTemplateGeneratorTests`, `DiarySanitizerTests`, `DiaryDraftViewModelTests`를 우선 작성하고, `DiaryAIClient`는 mock URLProtocol 또는 stub client로 request/response schema만 검증한다.

## 17. 추천 폴더 구조

```text
VictoryFairy/
  App/
    VictoryFairyApp.swift
    AppRootView.swift
  Core/
    Extensions/
    Utilities/
    Constants/
  DesignSystem/
    VFColor.swift
    VFTypography.swift
    VFMetricCard.swift
    VFResultBadge.swift
  Domain/
    Models/
      Team.swift
      Stadium.swift
      AttendanceLog.swift
      GameResult.swift
    Diary/
      DiaryDraft.swift
      DiaryWritingTone.swift
      DiaryMoodTag.swift
      DiaryHighlightTag.swift
    Stats/
      SeasonStats.swift
      StadiumStats.swift
      TeamMatchupStats.swift
  Data/
    Persistence/
      SwiftDataContainer.swift
      AttendanceLogEntity.swift
    Repositories/
      AttendanceLogRepository.swift
      LocalAttendanceLogRepository.swift
    Seed/
      kbo_teams.json
      kbo_stadiums.json
      SeedDataProvider.swift
    Remote/
      DiaryAIClient.swift
      DiaryDraftRequestDTO.swift
      DiaryDraftResponseDTO.swift
  Services/
    StatisticsService.swift
    VictoryFairyIndexService.swift
    Diary/
      DiaryTemplateGenerator.swift
      DiarySanitizer.swift
      DiaryDraftService.swift
  Features/
    Home/
      HomeView.swift
      HomeViewModel.swift
      HomeDashboardView.swift
    Feed/
      FeedView.swift
      FeedViewModel.swift
      AttendancePostCard.swift
    LogEditor/
      LogEditorView.swift
      LogEditorViewModel.swift
      TeamPickerView.swift
      StadiumPickerView.swift
    LogDetail/
      LogDetailView.swift
      LogDetailViewModel.swift
    DiaryDraft/
      DiaryDraftSheet.swift
      DiaryDraftViewModel.swift
      DiaryTonePicker.swift
      DiaryTagPicker.swift
    Statistics/
      StatisticsView.swift
      StatisticsViewModel.swift
      StadiumStatsView.swift
      SeasonStatsView.swift
    Calendar/
      CalendarView.swift
      CalendarViewModel.swift
      CalendarMonthView.swift
      CalendarDayCell.swift
      CalendarResultDot.swift
      CalendarDayDetailSheet.swift
    ProfileSettings/
      ProfileSettingsView.swift
      ProfileSettingsViewModel.swift
    ShareCard/
      ShareCardPreview.swift
      ShareCardViewModel.swift
  Resources/
    Assets.xcassets
  Tests/
    StatisticsServiceTests.swift
    VictoryFairyIndexServiceTests.swift
    DiaryTemplateGeneratorTests.swift
    DiarySanitizerTests.swift
```

핵심 컴포넌트는 `AttendancePostCard`, `CalendarMonthView`, `CalendarDayCell`, `CalendarResultDot`, `CalendarDayDetailSheet`, `ShareCardPreview`를 우선 설계한다. 이 컴포넌트들은 단순 데이터 표시가 아니라 피드형 기록, 시즌 캘린더, 공유 가능한 카드라는 제품 정체성을 드러내는 UI 단위다.

## 18. 디자인/브랜딩 방향

### 전체 디자인 톤

야구 팬덤의 즐거움은 살리되 유치한 캐릭터 앱처럼 보이지 않게 한다. "스포츠 기록장 + 개인 대시보드"를 넘어 "직관 시즌 다이어리 + 피드형 post + 시즌 캘린더" 느낌을 우선한다. 디자인 AI가 러프 와이어프레임으로 해석하지 않도록, 모든 주요 화면은 실제 서비스 스크린처럼 사진/스코어보드/카드 질감/결과 컬러/캡션/태그가 포함된 하이파이 UI를 기준으로 한다.

### 핵심 시각 컨셉

- Instagram-like feed card: 직관 기록은 정보 행이 아니라 하나의 post/card처럼 보여준다.
- season calendar: 시즌 전체를 월별 캘린더로 회고하는 구조를 핵심 시각 언어로 사용한다.
- ticket/post card: 카드에는 티켓 stub의 리듬과 소셜 post의 여백감을 결합한다.
- scoreboard hero: 사진이 없는 기록도 스코어보드형 hero header로 완성도 있게 보이게 한다.
- stadium light gradient: 홈 hero, 빈 상태, 공유 카드에 야구장 조명에서 온 은은한 gradient를 사용한다.
- baseball diary caption: 한 줄 메모는 단순 note가 아니라 경기의 감정을 담은 caption처럼 표현한다.
- shareable story card: 추후 SNS 스토리/피드 공유에 바로 확장 가능한 구도를 고려한다.

### 하이파이 디자인 기준

- 화면은 grayscale wireframe처럼 보이면 실패로 간주한다. 실제 앱처럼 컬러, 타이포, 카드, 이미지 영역, 배지, 필터, 캡션 상태가 모두 들어가야 한다.
- 피드 카드에는 반드시 사진 또는 scoreboard hero가 있어야 하며, 단순 텍스트 리스트로 만들지 않는다.
- 캘린더에는 result dot 색상, 선택 상태, bottom sheet preview가 함께 있어야 한다.
- 홈은 단순 metric card 나열이 아니라 이번 시즌을 대표하는 scoreboard hero와 승리요정 지수를 첫 화면 신호로 둔다.
- 통계 화면은 숫자만 나열하지 않고 해석 문구, 비교 가능한 랭킹, mini chart를 함께 제공한다.
- 팀 컬러는 accent로 제한하고, 전체 화면을 특정 팀 컬러로 도배하지 않는다.
- 카드 radius는 8px 안팎을 기본으로 하고, 과한 둥근 카드/장식적 캐릭터/포털형 정보 과밀을 피한다.
- iPhone 실제 화면 기준으로 텍스트가 잘리지 않고, 결과 배지와 점수는 한눈에 읽히는 크기와 대비를 가진다.

### 컬러 방향

- 기본 배경: off-white 또는 system background
- 강조색: 잔디 green, 스코어보드 navy, 승리 accent red 중 1~2개
- 팀 컬러: 카드의 작은 accent, 배지, 필터에 제한적으로 사용
- 한 화면 전체가 특정 팀 컬러로 과하게 물들지 않게 한다.

### 야구장 느낌 UI 요소

- 스코어보드형 결과 strip
- 베이스 다이아몬드 모티프를 작은 아이콘/빈 상태에 사용
- 구장별 카드에 field/stadium 라벨
- 티켓 stub 느낌의 피드 카드. 단, 과한 찢어진 티켓 장식은 피한다.

### 데이터 앱 느낌 UI 요소

- metric card: 총 경기, 승률, 평균 득점
- 작은 막대 차트와 순위 리스트
- 결과 색상: 승 green, 패 red, 무 gray, 취소 muted
- 시즌/구장/상대팀 필터 chip

### 귀여움을 넣는 방법

- 캐릭터보다 마이크로카피와 배지명으로 표현한다.
- "전설의 승리요정", "표본 수집 중" 같은 문구를 사용하되 결과를 과장하지 않는다.
- 일러스트는 빈 상태나 공유 카드에 제한적으로 사용한다.

### 카드 디자인

- 홈 대시보드 카드: 8px radius, 얇은 border, 큰 숫자와 짧은 해석.
- 통계 차트: 복잡한 그래프보다 top 3 리스트와 막대.
- 직관 피드 카드: 사진 또는 scoreboard hero, 날짜, 매치업, 결과, 구장, 점수, 캡션, 태그, 자세히 보기.
- 공유 카드: 스토리형 세로 비율과 피드형 정사각 비율을 모두 고려한다.

### 빈 상태 문구

- "첫 직관을 기록하면 승리요정 지수가 시작돼요."
- "아직 이 구장 기록이 없어요."
- "이번 시즌 기록이 비어 있어요. 첫 경기를 남겨볼까요?"

### 마이크로카피 예시

- 저장 완료: "직관 기록을 저장했어요."
- 점수 불일치: "결과와 점수가 맞지 않는 것 같아요. 그래도 저장할까요?"
- 표본 부족: "아직은 운보다 표본이 더 필요해요."

### 앱 아이콘 컨셉 후보

- 야구공 + 작은 별/날개 모티프
- 스코어보드 숫자 `W` + 야구공
- 홈플레이트 위 반짝임
- 배트/공보다 "승리 기록"을 상징하는 W 배지

### 앱스토어 스크린샷 콘셉트

1. "내 직관 승률을 한눈에"
2. "직관한 경기를 피드처럼"
3. "시즌 캘린더로 돌아보기"
4. "구장별·상대팀별 성적 분석"
5. "나는 진짜 승리요정일까?"

## 19. 기능 우선순위 로드맵

| 단계 | 목표 | 포함 기능 | 제외 기능 | 난이도 | 사용자 가치 | 리스크 |
|---|---|---|---|---|---|---|
| MVP 0.1: 로컬 직관 기록과 피드 카드 | CRUD와 핵심 post/card 경험 구축 | 팀/구장 seed, 로그 등록/수정/삭제, 상세, 수동 한 줄 메모, 수동 다이어리 입력 필드, 홈 요약, 피드 카드 기본 | 사진, 고급 통계, AI | 낮음~중간 | 기록 시작과 제품 정체성 확인 | 피드 카드가 단순 리스트처럼 보이면 실패 |
| MVP 0.2: 캘린더와 통계 overview | 시즌 회고와 데이터 앱 가치 구현 | 캘린더 month view, result dot, 홈 요약 강화, 승률, 시즌/구장/상대 통계, 승리요정 지수 | 공유, 서버 기반 AI | 중간 | 반복 사용 이유 확보 | 통계 정책과 캘린더 예외 처리 |
| MVP 0.3: 사진/태그/다이어리/공유 preview | 감성 기록과 공유 가능성 보강 | 사진 첨부, 추천 태그, 다이어리 강화, 캘린더 상세 bottom sheet, 템플릿 기반 직관 다이어리 자동 문장 생성, 분위기/하이라이트/말투 선택 UI, 공유 카드 preview | 실제 SNS 공유, 서버 기반 LLM | 중간 | 기록의 추억 가치 증가 | 저장 용량/권한/디자인 품질 |
| v1.0: 홈/피드/캘린더/통계 완성 후 출시 | 핵심 4탭 안정화 | 온보딩, 홈, 피드, 캘린더, 통계, ProfileSettings, 빈 상태, 샘플, 테스트, 접근성 | 친구/동기화 | 중간 | 실제 출시 가능 | 마이그레이션 준비 |
| v1.1: AI 후기 초안/공유 이미지/시즌 리포트 | 바이럴과 작성 보조 | 서버 기반 LLM 직관 다이어리 초안 생성, SNS 공유 이미지, 시즌 리포트, 공유 문구/해시태그 생성, AI 사용량 제한/보안 고지 | 친구 피드 본격 운영 | 중간~높음 | 공유와 재방문 증가 | 디자인 품질, AI 비용/보안 |
| v1.2: 서버 동기화/백업/AI 회고 | 데이터 안정성과 회고 강화 | iCloud/계정 백업, CSV export/import, 시즌 리포트 AI 요약, 월간 직관 회고 생성, 공유 이미지 문구 자동 생성 | 랭킹 | 중간~높음 | 장기 사용 신뢰 | 개인정보/비용 |
| v2.0: 친구 피드/공유 기능 | 소셜 확장 | 친구 피드, 친구 기록 공유, 그룹 직관, 비교 | 공식 자동 데이터 전체 | 높음 | 네트워크 효과 | 운영/신고/프라이버시 |
| v3.0: 실제 KBO 경기 데이터 연동 | 자동화 | 일정/결과 후보 추천, 매칭 | 비허가 크롤링 | 높음 | 입력 부담 감소 | 저작권/계약/API 안정성 |

## 20. 외부 데이터 연동 가능성

### KBO 공식 데이터 연동 가능성

KBO는 공식 사이트와 공식 앱을 통해 일정, 기록, 구단 정보를 제공한다. 다만 일반 개발자가 자유롭게 사용할 수 있는 공개 API가 명확히 제공되는지는 별도 확인이 필요하다. 상업적 앱에서 일정/결과/기록 데이터를 자동 반영하려면 KBO 또는 데이터 제공사와의 이용 조건 확인이 필요하다.

### 네이버 스포츠/다음 스포츠 참고 시 주의점

포털 스포츠 페이지의 경기 일정/결과는 저작권, DB권, 서비스 이용약관, robots 정책이 얽힐 수 있다. 앱 기능의 핵심을 비공식 크롤링에 의존하면 차단, 법적 리스크, 데이터 오류, 심사 리스크가 생긴다.

### API가 없을 때의 대안

- 사용자가 직접 입력하는 MVP 유지
- 앱 내 KBO 팀/구장 seed만 제공
- 날짜/팀/구장 입력 후 "후보 경기"는 사용자가 확인해 선택하는 보조 기능으로 제한
- CSV import/export 제공
- 제휴 가능한 스포츠 데이터 제공사 검토

### 수동 입력 MVP의 장점

- 법적 리스크가 낮다.
- 서버 비용 없이 출시 가능하다.
- 사용자가 실제 직관한 경기만 남기므로 데이터의 의미가 명확하다.
- 점수/메모/좌석/사진처럼 공식 데이터에 없는 개인 맥락을 담을 수 있다.

### 나중에 자동 경기 매칭 방식

1. 사용자가 날짜를 선택한다.
2. 응원팀과 상대팀을 선택한다.
3. 로컬 seed 또는 합법 데이터 소스에서 해당 날짜 후보 경기를 찾는다.
4. 후보가 있으면 구장/홈원정/점수를 자동 제안한다.
5. 사용자가 직접 확인 후 저장한다.

### 서버가 필요한 시점

- LLM 기반 AI 직관 다이어리 초안 생성
- 여러 기기 동기화
- 공식/제휴 데이터 캐싱
- 친구/공유/랭킹
- 푸시 알림
- 시즌 리포트 서버 생성

### 크롤링을 피하고 합법적으로 접근하는 방향

- 공식 API/데이터 제휴 가능성 확인
- 사용 조건이 명확한 데이터 제공사 사용
- 앱 내에는 출처와 데이터 이용 범위를 표시
- 자동 수집 전 법무/약관 검토
- MVP에서는 수동 입력과 사용자 소유 데이터만 사용

## 21. 수익화 방향

### 무료 기본 기능

- 직관 로그 등록
- 기본 승률 통계
- 시즌/구장/상대팀 요약
- 로컬 저장

### 프리미엄 가능 기능

- 고급 통계: 좌석/동행자/요일/태그별 분석
- 시즌 리포트 PDF 또는 이미지
- 커스텀 테마와 팀 컬러 테마
- 공유 이미지 템플릿
- iCloud/서버 백업
- CSV export/import
- 위젯 고급 스타일
- 무료 사용자 일/월 n회 AI 초안 생성
- 프리미엄 사용자 추가 AI 생성 횟수
- 고급 말투, 시즌 리포트, 월간 회고, 공유 이미지 문구 생성

단, 기본 수동 기록과 로컬 통계는 무료로 유지한다. AI 기능은 사용자의 기록 경험을 보조하는 선택 기능이어야 하며, 핵심 기록 기능을 유료 AI 뒤에 숨기지 않는다.

### 광고 가능성

초기에는 추천하지 않는다. 기록 앱의 신뢰와 집중도를 해칠 수 있다. 광고를 넣더라도 로그 작성/통계 확인 플로우에는 넣지 않는 기준이 필요하다.

### 제휴 가능성

- 야구 굿즈
- 구장 주변 맛집/교통 정보
- 팬 이벤트
- 티켓 예매처 딥링크

### 경험을 해치지 않는 기준

- 기록 작성은 항상 무료와 빠른 UX 유지
- 사용자의 개인 기록을 잠그지 않는다.
- 프리미엄은 "더 깊은 분석/더 예쁜 공유/더 안전한 백업"에 둔다.
- 팬덤 감정을 과도하게 상업화하지 않는다.

## 22. 차별화 포인트

### 핵심 차별점 5개

1. KBO 직관 팬만을 위한 직관 시즌 다이어리 앱
2. 피드형 post/card로 남기는 예쁜 직관 기록
3. 캘린더에서 돌아보는 시즌별 직관 히스토리
4. 내가 본 경기만 계산하는 직관 승률과 승리요정 지수
5. 수동 입력 MVP로 시작해 데이터 권리 리스크를 낮춘 구조

### 초기 유저가 좋아할 포인트

- "내가 가면 이기는지" 바로 확인 가능
- 직관한 경기가 피드와 캘린더에 쌓이는 재미
- 시즌 직관 횟수와 성적이 자동으로 쌓임
- 구장별 성적/방문 횟수가 팬심을 자극
- 친구에게 공유하기 좋은 결과 화면으로 확장 가능

### 앱스토어 키워드

KBO, 야구, 직관, 야구 기록, 승률, 야구장, 응원, 경기 기록, 스포츠 다이어리, 라이프로그, 승리요정

### 커뮤니티/바이럴 가능성

- `나의 2026 직관 성적`
- `나는 승리요정인가`
- `내 직관 시즌 피드`
- `직관 캘린더 인증`
- `구장별 승률 카드`
- `친구별 승률`
- `올해 원정 도장깨기`

### 감정적 재미와 데이터 결합

승리요정은 미신처럼 말하던 팬덤 표현을 데이터로 장난스럽게 확인해준다. 다만 앱은 "원인"을 주장하지 않고 "내 기록상 이런 결과"라고 표현해야 한다.

## 23. 첫 개발 태스크 목록

| 태스크명 | 목적 | 관련 화면/모듈 | 예상 산출물 | 선행 조건 | 우선순위 | 완료 기준 |
|---|---|---|---|---|---|---|
| Xcode 프로젝트 생성 | 앱 기본 실행 환경 구성 | App | SwiftUI iOS 프로젝트 | 없음 | P0 | 시뮬레이터 실행 |
| 새 탭 구조 적용 | 정보 구조 확정 | Home/Feed/Calendar/Statistics | TabView | 프로젝트 생성 | P0 | 홈/피드/캘린더/통계 4개 탭 이동 |
| KBO 팀/구장 seed 작성 | 선택 데이터 제공 | Data/Seed | JSON + provider | 공식 정보 재확인 | P0 | 팀/구장 picker 표시 |
| AttendanceLog 모델 설계 | 핵심 데이터 저장 | Domain/Data | SwiftData model | 저장 방식 결정 | P0 | 모델 생성/저장 |
| 피드/캘린더용 AttendanceLog 필드 설계 | post/card와 calendar 표시 기반 마련 | Domain/Data | captionText, photoLocalPaths, tagNames, feedVisibility/isShareable, calendarDisplayResult, createdAt, updatedAt | AttendanceLog 모델 설계 | P0 | 카드/캘린더 표시 필드 저장 가능 |
| 로컬 저장 repository 구현 | CRUD 추상화 | Data | Repository protocol/impl | 모델 설계 | P0 | create/read/update/delete |
| 직관 로그 등록 화면 구현 | 핵심 입력 루프 | LogEditor | Form UI | seed/repository | P0 | 필수값 저장 성공 |
| 메모/다이어리 입력 영역 추가 | AI 없이도 완성되는 기록 경험 제공 | LogEditor/LogDetail | shortMemo field, diaryText editor | 로그 등록 화면 | P0 | 수동 입력/수정/표시 가능 |
| AttendancePostCard 설계 | 제품 정체성의 핵심 카드 구현 | Feed/DesignSystem | 사진/scoreboard header, 결과 배지, 캡션, 태그, 자세히 보기 | 모델/repository | P0 | 저장한 로그가 post card로 표시 |
| FeedView 기본 구현 | 피드형 기록 탐색 | Feed | 최근순 카드 리스트, 시즌/결과 필터 | AttendancePostCard | P1 | 피드에서 저장한 로그 탐색 가능 |
| CalendarView 기본 month grid | 캘린더 핵심 탭 구현 | Calendar | 월 그리드, result dot, 날짜 선택 | 모델/repository | P0 | 기록 날짜에 결과 dot 표시 |
| HomeDashboardView 수정 | 시즌 다이어리 홈 경험 구현 | Home | 시즌 요약, 승리요정 지수, 최근 직관, 빠른 기록 추가 | 통계 서비스 | P0 | 홈에서 시즌 상태와 최근 직관 확인 |
| 경기 상세/수정 화면 구현 | 기록 관리 | LogDetail | 상세/수정/삭제 | FeedView | P0 | 수정/삭제 반영 |
| 기본 통계 계산 서비스 | 데이터 가치 제공 | Services/Statistics | 순수 계산 로직 | 샘플 로그 | P0 | 단위 테스트 통과 |
| 통계 화면 구현 | 분석 기능 제공 | Statistics | 시즌/구장/상대 통계 | 통계 서비스 | P1 | 그룹 통계 표시 |
| 승리요정 지수 구현 | 브랜드 재미 구현 | Services/Home | 지수/등급 | 결과 통계 | P1 | 표본 부족/등급 처리 |
| 샘플 데이터 추가 | 개발/디자인 검증 | Data/Preview | Preview fixtures | 모델 | P1 | Preview에서 통계 확인 |
| 빈 상태/에러 상태 구현 | UX 완성도 | 전체 | Empty/error views | 주요 화면 | P1 | 로그 0개 상태 자연스러움 |
| 기본 디자인 시스템 생성 | 일관된 UI | DesignSystem | Color/type/card/badge | 화면 초안 | P1 | 주요 화면 공통 컴포넌트 사용 |
| 단위 테스트 작성 | 회귀 방지 | Tests | Stats tests | 통계 서비스 | P1 | 승률/취소/무 처리 검증 |
| CalendarDayDetailSheet 구현 | 날짜별 기록 확인/추가 연결 | Calendar | bottom sheet, 해당 날짜 경기 카드, 추가 CTA | CalendarView | P1 | 날짜 선택 시 경기 목록/추가 진입 표시 |
| ProfileSettings 진입 추가 | 설정을 탭 밖으로 이동 | Home/ProfileSettings | 홈 우측 상단 아이콘, 설정 화면 | HomeDashboardView | P1 | 응원팀/데이터/AI 안내 접근 가능 |
| 분위기/하이라이트/말투 enum 설계 | 템플릿과 AI 입력값 표준화 | Domain/Diary | DiaryMoodTag, DiaryHighlightTag, DiaryWritingTone | 다이어리 필드 | P1 | 선택값 저장/표시 가능 |
| DiaryTemplateGenerator 구현 | 외부 API 없는 문장 자동 채우기 | Services/Diary | 로컬 템플릿 생성기 | enum 설계 | P1 | 경기 정보 기반 문장 생성 |
| 템플릿 기반 문장 자동 채우기 UI | 작성 부담 감소 | LogEditor/DiaryDraft | `문장 자동 채우기` 버튼 | TemplateGenerator | P1 | 사용자가 적용해야 본문 반영 |
| 사진 첨부 구현 | 피드 카드의 시각적 매력 강화 | LogEditor/Detail/Feed | PhotosPicker + local file + 카드 썸네일 | MVP CRUD | P2 | 사진 저장/표시 |
| 태그 입력 구현 | 피드/통계의 감성 맥락 강화 | LogEditor/Feed | 추천 태그 선택 UI | 모델 | P2 | 카드에 태그 표시 |
| ShareCardPreview 구현 | 공유 확장 전 카드 포맷 검증 | ShareCard | preview screen/card | AttendancePostCard | P2 | 기록 기반 공유 preview 표시 |
| AI 서버 API 설계 문서 작성 | 서버 기반 LLM 연동 준비 | API/Docs | `/api/v1/ai/diary-draft` 스펙 | 보안 원칙 확정 | P2 | request/response와 제한 정책 문서화 |
| DiaryDraftRequest/Response DTO 설계 | iOS-서버 계약 정의 | Data/Remote | DTO 타입 | API 스펙 | P2 | 민감 정보 제외 schema |
| DiaryAIClient stub 작성 | 실제 서버 전 UI 개발 가능 | Data/Remote | stub client | DTO 설계 | P2 | mock 응답으로 preview 동작 |
| 보안 고지 UI 설계 | 사용자 동의와 투명성 확보 | DiaryDraft/ProfileSettings | 전송 항목 안내 UI | API 스펙 | P2 | AI 요청 전 고지 표시 |
| 실제 LLM 서버 연동 | AI 초안 생성 제공 | Server/Data Remote | API server + client 연동 | 서버 준비 | P3 | iOS에 API Key 없이 초안 생성 |
| 사용량 제한/비용 로깅 | 비용 폭주 방지 | Server | rate limit, usage logs | 서버 연동 | P3 | 일/월 제한과 token logging |
| AI 결과 검증/필터링 | 부적절한 결과 방지 | Server/App | JSON schema, safety check | 서버 연동 | P3 | 검증된 필드만 앱 표시 |

## 24. 최종 파일 생성 요구사항

이 문서는 다음 요구사항을 충족하도록 작성되었다.

1. 승리요정 iOS 앱의 서비스 기획, MVP 범위, 화면 구조, 데이터 모델, 통계 로직, 구현 방향을 Markdown으로 정리했다.
2. 프로젝트 루트에 `docs` 디렉터리를 생성하는 것을 전제로 한다.
3. 저장 경로는 `docs/VictoryFairy_iOS_App_Planning.md`다.
4. 저장 후 파일 존재 여부를 확인해야 한다.
5. 다음 개발 시작 시 우선순위는 `새 탭 구조 적용`, `AttendancePostCard 설계`, `CalendarView 기본 month grid`, `HomeDashboardView 수정`이다.

## 변경 이력

- 2026-05-01: AI 직관 다이어리 보조 기능 추가
- 2026-05-01: LLM API Key를 iOS 앱에 포함하지 않는 서버 기반 AI 보안 설계 추가
- 2026-05-01: AI payload 최소화, 사용자 검토 후 저장, 비용 제어, 장애 대응 정책 추가
- 2026-05-02: 앱 컨셉을 “KBO 직관 시즌 다이어리”로 강화
- 2026-05-02: Instagram-like 피드형 기록 경험 추가
- 2026-05-02: 캘린더를 핵심 탭으로 승격
- 2026-05-02: 하단 탭 구조를 홈/피드/캘린더/통계로 재정의
