# 백엔드 요청 — 프로필 편집(닉네임·사진) (2026-08-31)

앱팀입니다. 시안의 **프로필 편집**(설정 화면 `977:662` 의 이름 옆 연필)을 붙이려는데
저장할 곳이 없어서 화면을 만들지 못했습니다. 저장소를 열어 확인한 현황과, 필요한 것만 정리했습니다.

## 확인한 현황 (앱팀이 코드로 확인)

| 항목 | 현황 |
|---|---|
| 닉네임 변경 API | **없습니다.** `PATCH /v1/auth/me` 는 `accessFeatures` 만 받고, 그 키가 없으면 `400 nothing_to_update` 를 돌려줍니다 (`src/server/auth-routes.ts:519`). `nickname` 을 실어 보내도 무시됩니다. |
| 지금 닉네임이 바뀌는 유일한 경로 | 글·후기·플랜 저장의 `authorNm` **부수효과** (`update authors set nickname = coalesce(nullif($2,''), nickname)` — `src/server/app.ts` 여러 곳). 글을 쓰지 않으면 바꿀 방법이 없습니다. |
| 프로필 사진 | **컬럼부터 없습니다.** `authors` 에 아바타 관련 컬럼이 없고(024·030 까지 확인), 저장소 전체에 `avatar`/`profileImage` 류 코드가 0건입니다. |
| 이미지 업로드 인프라 | **이미 있습니다.** `POST /v1/reviews/images` (multipart, `files` 필드, URL 배열 반환, 서버 리사이즈 없음 — iOS 가 장변 1280·JPEG q0.8 로 줄여 올림). |

앱은 저장이 안 되는 화면을 만들지 않기로 했습니다. 로컬에만 저장하면 기기를 바꾸면 사라지고
다른 사용자에게는 보이지 않아서, 없는 것보다 오해를 만듭니다.

---

## 요청 1. `PATCH /v1/auth/me` 가 `nickname` 을 받게 (작은 변경, 마이그레이션 불필요)

```jsonc
// PATCH /v1/auth/me
{ "nickname": "대원" }                       // accessFeatures 없이 이것만 와도 200
{ "nickname": "대원", "accessFeatures": [] }  // 함께 와도 됨
```

- **부분 갱신을 허용해 주세요.** 지금은 `accessFeatures === undefined` 면 `nothing_to_update` 로 막히는데,
  `nickname` 만 온 요청도 유효한 갱신으로 처리해 주시면 됩니다. (둘 다 없을 때만 `nothing_to_update`)
- 검증은 가입 라우트의 규칙을 그대로 쓰면 충분합니다 — `MAX_NICKNAME_LENGTH` 초과 시 `400 invalid_nickname`.
  앞뒤 공백 트림 후 **빈 문자열이면 `400 invalid_nickname`** 이 앱에 편합니다("지우기"가 아니라 잘못된 입력이라).
- 응답은 지금의 `AuthorView` 그대로면 됩니다(이미 `nickname` 이 들어 있습니다) — 앱이 그 값으로 화면을 갱신합니다.

> 참고: 서버가 `authorNm` 으로 닉네임을 갱신하는 기존 동작은 그대로 두셔도 됩니다. 앱은
> 프로필에서 바꾼 이름을 다음 글 작성의 기본값으로도 씁니다(`ReviewAuthorStore`).

## 요청 2. 프로필 사진

### 2-1. 컬럼
```sql
-- sql/0NN_author_avatar.sql
alter table authors add column if not exists avatar_url text;
```

### 2-2. `PATCH /v1/auth/me` 가 `avatarUrl` 도 받게
```jsonc
{ "avatarUrl": "https://…/uploads/reviews/ab12….jpg" }  // 설정
{ "avatarUrl": null }                                    // 제거(기본 아바타로)
```
- `null` 과 **키 없음**을 구분해 주세요 — `null` = 지우기, 없음 = 그대로.
- 값 검증은 길이 상한과 `https` 스킴 정도면 충분합니다.

### 2-3. 응답에 포함
- `GET /v1/auth/me` · `PATCH /v1/auth/me` 의 `AuthorView` 에 `avatarUrl` 추가.
- **그리고 남이 보는 자리에도** — 요청 3.

### 2-4. 업로드는 기존 라우트 재사용을 제안합니다
`POST /v1/reviews/images` 를 그대로 쓰고 반환된 URL 을 `avatarUrl` 로 보내는 방식이 가장 적습니다
(그 라우트 주석에 "파일명을 내용의 sha256 으로 정해 경로 접두사가 뜻을 갖지 않는다"고 되어 있어
앱도 후기·게시글에서 이미 같은 라우트를 공유합니다).
전용 경로(`/v1/auth/avatar` 등)가 낫다고 판단하시면 그쪽으로 맞추겠습니다 — 앱 변경은 한 줄입니다.

---

## 요청 3. 남이 보는 자리에도 같은 사진 — **같은 라운드에 부탁드립니다**

프로필 사진을 올리는 이유가 **내 글에서 남에게 보이는 것**이라, 내 설정 화면에만 보이면 기능이 반쪽입니다.
처음에 하위호환을 걱정해 뒤로 미루자고 적었는데, **이미 서버가 그 문제를 해결한 방식이 있어** 철회합니다:

> `src/server/app.ts:752` — "기존 응답 필드는 그대로 두고(iOS 라이브 사용 중) 작성자 프로필만
> `authorInfo` 로 덧붙인다" → 후기 응답에 `authorInfo: {nickname, reviewCount, level}` 가 이미 그렇게 붙어 있습니다.

같은 패턴을 그대로 쓰면 구버전 앱은 영향이 없습니다. 기존 `author` 문자열은 **건드리지 말고 그대로** 두시면 됩니다.

### 3-1. 후기 계열 — `authorInfo` 에 한 필드
```jsonc
"author": "효도여행중",                      // 그대로
"authorInfo": { "nickname": "효도여행중", "reviewCount": 3, "level": 7,
                "avatarUrl": "https://…" }   // ← 이 한 줄 추가 (없으면 null)
```
적용 대상: 장소 후기 목록·상세, 후기 댓글 (앱이 `AuthorInfoDTO` 로 이미 파싱하고 있어 **앱 변경이 한 줄**입니다).

### 3-2. 게시글 계열 — 같은 모양으로
게시글 응답에는 `authorInfo` 가 아직 없습니다(`author: String` 만). 후기와 **같은 모양**으로 붙여 주시면
앱이 한 파서를 공유합니다:
```jsonc
"author": "효도여행중",
"authorInfo": { "nickname": "효도여행중", "avatarUrl": "https://…" }
```
적용 대상: 게시글 목록(`/v1/posts` — 홈 피드·저장 탭·내 게시글·장소별 게시글에 모두 쓰입니다), 게시글 상세, 게시글 댓글.
`reviewCount`·`level` 은 게시글에 필요 없으니 빼셔도 됩니다.

### 3-3. 레거시 행
후기는 `author_nm`(문자열)만 있고 `author_id` 가 없는 옛 행이 있습니다 — 그 경우 `avatarUrl: null` 로 두시면 됩니다.
앱은 사진이 없으면 지금처럼 이니셜 원을 그립니다.

## 앱이 할 일 (서버가 열리면)

- 설정 → 연필 → **프로필 편집 화면**: 사진 고르기(`PhotosPicker`, 장변 1280·q0.8 로 줄여 업로드 — 후기와 같은 경로)와
  닉네임 입력 → `PATCH /v1/auth/me` 한 번.
- 아바타 자리는 이미 설정 화면에 있습니다(라임 원 100 + 무장애 뱃지) — `avatarUrl` 이 오면 그 자리를 사진으로 바꿉니다.
- **남이 보는 자리**: `PostCard` · `PostDetailView` · `ReviewCard` · `PlaceReviewRow` · `ReviewDetailView` · 댓글 줄의
  이니셜 원을 사진으로 바꿉니다. 사진이 없으면 지금 모양 그대로입니다.

## 같은 시점의 다른 요청 2건

`docs/DESIGN_SYNC_2026-08-31.md` 의 A절에 함께 적어 두었습니다 — ① 추천 코스 **테마 라벨**이 시안과
겹치는 것이 하나뿐인 문제, ② `POST /v1/plans/recommend` 에 **혼잡도 선호 필드**(시안 4/6 의
"덜 붐볐으면 좋겠어요") 부재. 우선순위는 서버팀이 편한 순서대로 해 주세요.
