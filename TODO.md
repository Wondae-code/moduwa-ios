# TODO

디자인 시안이 없는 동안 진행할 백로그. 우선순위 순서는 아니고, 착수 시 항목을 위에서 지우고 커밋 메시지에 남긴다.

## 접근성 검증 (공모전 핵심 테마 — 우선)

- [ ] Xcode Accessibility Inspector로 홈 피드 전체 순회 감사 (Audit 탭 자동 진단 + 수동 VoiceOver 순회)
- [ ] Dynamic Type 최대 크기(AX5)에서 레이아웃 확인 — 특히 `HeroCard`의 해시태그 칩 줄바꿈, `PlaceCard`의 2열 그리드에서 텍스트 잘림 여부
- [ ] VoiceOver 순회 순서 확인 — 헤더 sticky화 이후 스크롤 콘텐츠와의 포커스 순서가 자연스러운지 (`moduwa/Features/Home/HomeView.swift`)
- [ ] `AccessibilityBadge`(`moduwa/Components/AccessibilityBadge.swift`)의 탭-확장 인터랙션이 VoiceOver로도 조작 가능한지 (현재 `Button` + `withAnimation`, 커스텀 제스처 아님 — 더블탭 확인만 하면 됨)
- [ ] 색약 대응 확인 — 브랜드 그린(`deepGreen`/`moduwaGreen`)과 텍스트 그레이의 대비, 접근성 뱃지 아이콘이 색상 없이도 형태로 구분되는지
- [ ] `ReviewCard`의 `+N` 오버레이 대비(흰 텍스트 on 검정 40% 스크림)가 저시력 사용자에게도 충분한지
- [ ] 결과를 바탕으로 Notion 허브의 접근성 가이드(MagentaA11y 등)와 대조해 공모전 제출 문서에 반영

## CI/CD

- [ ] GitHub Actions: PR마다 `xcodebuild build` 자동 실행 (지금은 매번 로컬에서 수동 실행 중)
- [ ] 가능하면 시뮬레이터 유닛 테스트도 CI에 포함 (아래 테스트 커버리지 항목 선행 필요)

## 테스트 커버리지

- [ ] XCTest 타겟 신설 — 현재 프로젝트에 테스트 타겟 자체가 없음
- [ ] `APIFeedService`의 순수 함수 단위 테스트: `pickFeature`, `shortRegion`, `cleanNote` (`moduwa/Services/APIFeedService.swift`)
- [ ] `HomeViewModel` 페이지네이션 로직 테스트: 맞춤 추천 더보기(+6), 리뷰 더보기(+5), 카테고리/정렬 전환 시 첫 페이지 리셋 (`moduwa/Features/Home/HomeViewModel.swift`)

## 에러/로딩 상태

- [ ] `HomeViewModel.loadInitial`의 `// TODO: 에러 표시` 처리 — 현재 실패 시 조용히 무시됨
- [ ] 네트워크 폴백(API → 번들 JSON) 시 로딩 스피너 부재 — 초기 로드 UX 보강

## 미완성 탭

- [ ] 플랜/일정/저장 탭이 전부 `ContentUnavailableView` 플레이스홀더 — 디자인 없어도 빈 상태 화면 레이아웃은 먼저 구성 가능

## 시안 반영 스윕

- [ ] 피그마 "모두와 UI" 페이지의 "장소 상세"(node 133:110) 화면이 지난 확인 시점(2026-07-18) WIP였음 — 진전 있었는지 재확인 후 반영
