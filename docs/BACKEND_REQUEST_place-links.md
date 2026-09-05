# 요청 — 장소 링크 `https://moduwa.app/p/{contentId}` (2026-09-05)

장소 상세의 **공유하기**가 이제 카카오맵 링크 대신 **우리 링크**를 보냅니다. 앱 쪽은 다 됐고
(받는 쪽 라우팅까지 시뮬레이터에서 확인했습니다), **서버에서 두 가지가 열려야 링크가 살아납니다.**

지금 상태: `https://moduwa.app/p/4005073` → **404**. 앱이 깔린 기기에서도 AASA 에 `/p/*` 가
없어 앱이 열리지 않습니다.

---

## 1. AASA 에 `/p/*` 추가 (한 줄)

`src/server/app.ts:158`

```diff
- applinks: { details: [{ appIDs: config.web.appleAppIds, components: [{ '/': '/i/*' }] }] },
+ applinks: {
+   details: [{
+     appIDs: config.web.appleAppIds,
+     components: [{ '/': '/i/*' }, { '/': '/p/*' }],
+   }],
+ },
```

⚠️ **애플 CDN 캐시**: 이미 설치된 기기는 AASA 를 다시 받아야 반영됩니다(앱 재설치 또는 며칠).
그래서 **심사에 내기 전에 먼저 올려 두는 편**이 좋습니다.

## 2. `GET /p/:contentId` 대체 페이지

`/i/:code` 와 같은 역할입니다 — **앱이 깔려 있으면 이 페이지는 뜨지 않습니다.** 여기 도달했다는
것은 앱이 없거나, 카톡 인앱 웹뷰처럼 유니버설 링크가 발동하지 않는 경로로 열었다는 뜻입니다.

필요한 것:

| | 내용 |
|---|---|
| 검증 | `contentId` 는 **숫자만** 통과(`/^\d+$/`). 아니면 404 — 파라미터를 화면에 되돌리지 않습니다(`/i/:code` 와 같은 규칙) |
| 내용 | 장소 이름 · 주소 · **무장애 항목** · 대표 사진. 없는 contentId 면 "찾을 수 없는 장소" 안내 |
| 버튼 | `moduwa://p/{contentId}` → "앱에서 열기" (인앱 웹뷰 폴백, 앱이 이 스킴을 이미 받습니다) |
| 버튼 | `config.web.appStoreUrl` 있으면 "앱 받기" |
| 출처 | 무장애 정보를 표시하면 **"한국관광공사 TourAPI"** 한 줄 (표출 시 출처 표시 의무) |

### OG 태그를 꼭 넣어 주세요

카카오톡 대화창에서 링크가 **카드로 보이느냐 파란 글씨로 보이느냐**가 여기서 갈립니다.

```html
<meta property="og:title"       content="{장소 이름} — 모두와">
<meta property="og:description" content="{주소} · 무장애: 휠체어 접근, 청각 지원">
<meta property="og:image"       content="{firstimage}">
<meta property="og:url"         content="https://moduwa.app/p/{contentId}">
```

⚠️ 값은 **이스케이프**해서 넣어 주세요(장소 이름에 따옴표가 들어오는 경우가 있습니다).

---

## 앱이 이미 하는 일 (참고)

- 공유 글에 `https://moduwa.app/p/{contentId}` 를 싣습니다(`PlaceLink`).
- 링크를 받으면 `RootView.open(_:)` 이 `/i/`(초대)와 `/p/`(장소)를 갈라 각각 플랜·홈 탭으로
  보냅니다. 장소는 홈이 상세를 받아 화면을 밉니다.
- `moduwa://p/{contentId}` 커스텀 스킴도 같은 길로 흐릅니다 — **이미 동작을 확인했습니다**
  (콜드 스타트에서 상세까지 열림).
- 관광공사 contentId 가 아닌 값(번들·목 데이터)에는 링크를 만들지 않고 카카오맵 링크로 물러납니다.

## 여담 — 이미 되어 있던 것

`/privacy`, `/terms` 가 이미 200 으로 떠 있어서 앱의 "준비 중" 자리를 그 주소로 연결했습니다.
따로 요청드릴 것이 없었습니다.
