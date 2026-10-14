<h1 align="center">
  <img src=".github/assets/icon.png" alt="모두와 (moduwa)" width="128">
</h1>

<p align="center">
  나이, 장애에 상관없이, 누구와 함께하든,<br>
  모두의 즐거운 여행을 바라는 모두와에요.
</p>

<p align="center">
  <a href="https://apps.apple.com/kr/app/id6806744787">App Store에서 받기</a>
</p>

모두와(moduwa)의 iOS 앱 저장소입니다.

지도와 여행 앱은 그곳에 장소가 있다는 것까지만 알려 줍니다. 입구에 턱이 있는지, 경사로나 엘리베이터가 있는지는 가 봐야 압니다.
모두와는 한국관광공사의 무장애 여행 데이터(1만여 곳)와 여행자 후기를 합쳐서, 휠체어 이용자, 시각·청각 장애인, 고령자, 영유아 동반 여행자가 갈 수 있는 곳을 미리 알려 줍니다.
후기는 **나와 같은 접근성 조건을 가진 사람의 것부터** 보여 줍니다.

『2026 관광데이터 활용 공모전』 출품작입니다.

## 주요 기능

- **장소 탐색** — 내 무장애 조건에 맞춰 관광지·맛집·숙소·축제를 추천합니다. 장소 상세에는 무장애 속성 28종, 지도, 후기가 나오고, 본문을 소리로 읽어 주는 기능도 있습니다.
- **여행 플랜** — 지역·기간·테마·이동 수단(자차·뚜벅이·휠체어)을 고르면 코스를 추천해 줍니다. 일정은 하루 단위로 고치고, 초대 링크로 다른 사람과 함께 편집할 수 있습니다.
- **후기와 게시글** — 사진 후기, 여행 게시글, 좋아요·댓글, 신고·차단을 지원합니다.
- **앱 자체의 접근성** — 글자 크기 조절, 고대비 모드, VoiceOver를 지원합니다.

## 기술 스택

| | |
|---|---|
| 언어·UI | Swift, SwiftUI · iOS 17+ |
| 구조 | 공유 상태는 `@Observable` 스토어에 둡니다. 서비스는 프로토콜로 정의해 `@Environment`로 주입하고, 프리뷰에서는 목 구현으로 바꿉니다 |
| 로그인 | Sign in with Apple, Kakao SDK, Google(SDK 없이 `ASWebAuthenticationSession` + PKCE), 이메일 |
| 지도 | Kakao Maps SDK (장소 위치, 플랜 경로, 위치 고르기) |
| 그 밖 | APNs 푸시, `AVSpeechSynthesizer` 읽어 주기, 키체인 토큰 보관 |
| 서버 | [moduwa-backend](https://github.com/Wondae-code/moduwa-backend) (Hono·TypeScript REST API, PostgreSQL, Railway) |
| 데이터 | 한국관광공사 TourAPI (국문 관광정보, 무장애 여행정보 등). 서버가 받아 가공하고, 앱은 서버 API만 호출합니다 |
| 배포 | TestFlight 업로드 스크립트(`scripts/`), Xcode Cloud(`ci_scripts/`) |

SPM으로 직접 넣은 패키지는 Kakao SDK와 Kakao Maps SDK 두 개이고, Kakao SDK가 Alamofire를 함께 가져옵니다. 광고·분석·트래킹 SDK는 없습니다.

## 폴더 구조

```
moduwa/
├── App/            루트 뷰(탭 구성), AppDelegate
├── Features/       화면별 모듈 (Home, PlaceDetail, Plan, PlanCreate, Auth …)
├── Components/     여러 화면이 함께 쓰는 뷰
├── DesignSystem/   색·타이포·간격 토큰
├── Services/       API 클라이언트, 인증, 푸시
└── Models/
docs/               백엔드 요청서, QA 기록 등 작업 문서
TestFlight/         심사 노트, 릴리스 노트
scripts/            TestFlight 업로드 스크립트
ci_scripts/         Xcode Cloud 빌드 스크립트
```

## 빌드하기

Xcode 16 이상이 필요합니다.

1. `Secrets.plist.example`을 `moduwa/Resources/Secrets.plist`로 복사합니다.
2. 아래 세 값을 채웁니다. 이 파일은 `.gitignore`에 들어 있어 저장소에 올라가지 않습니다.
   - `MODUWA_API_KEY` — moduwa-backend API 키 (서버 운영자에게 발급)
   - `KAKAO_NATIVE_APP_KEY` — Kakao Developers 네이티브 앱 키
   - `GOOGLE_IOS_CLIENT_ID` — Google Cloud의 iOS OAuth 클라이언트 ID
3. `moduwa.xcodeproj`를 열고 실행합니다.

키가 없어도 빌드는 되지만, 서버 데이터와 지도, 소셜 로그인은 동작하지 않습니다.

## 데이터 출처

장소 정보, 무장애 속성, 관광 사진은 [한국관광공사 TourAPI](https://api.visitkorea.or.kr)에서 제공받습니다.
