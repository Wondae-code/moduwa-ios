# 요청 — 홈 추천을 "나와 같은 접근성" 우선으로 (2026-09-06)

홈 "여행자 리뷰"의 **추천 정렬**이 반응 수(`like_count + comment_count`)만 봅니다. 접근성이
주제인 앱에서 추천이 인기순이면 **나와 상관없는 조건의 글이 위에 섭니다** — 휠체어로 다니는
사람에게 시각장애 후기가 먼저 오는 식입니다.

앱은 이미 고쳤습니다(`HomeViewModel.feedItems`): **① 내 무장애 축과 겹치는 수 → ② 반응 수 →
③ 최신**. 그런데 **받아 온 페이지 안에서만 다시 세울 수 있어서 반쪽입니다.** 서버가 여전히
반응 수로 페이지를 자르기 때문입니다.

## 왜 앱만으로는 안 되는지 (지금 데이터로)

`GET /v1/reviews?sort=recommended&limit=5` — 후기 12건 중 방문 조건 태그가 붙은 것은 **1건**입니다.

| 순위 | id | 반응 | 작성일 | 장소 | 태그 |
|---|---|---|---|---|---|
| 0 | 2 | 3 | 07-11 | 강릉 녹색도시체험센터 | barrier_free, kids |
| 1 | 3 | 3 | 07-09 | 무릉별유천지 | barrier_free, parking |
| 2 | 4 | 3 | 07-07 | 롯데호텔 제주 | barrier_free, kind |
| 3 | 1 | 2 | 07-12 | 정남진 편백숲 우드랜드 | barrier_free, silver |
| 4 | 6 | 1 | 06-30 | 무창포 비체팰리스 | barrier_free, silver |
| **5** | **15** | **0** | **09-06** | **허스크밀** | taste, **`visit_visual`** |

시각장애 축을 고른 사람에게 딱 맞는 후기가 **id=15 하나뿐인데, 반응이 0 이라 6위 → 2페이지**입니다.
`limit=5` 인 홈에는 **영원히 오지 않습니다.** 앱이 아무리 다시 세워도 손에 없는 것은 못 올립니다.

(게시글 쪽은 앱만으로 됩니다 — `/v1/posts` 를 10건씩 받고 전체가 10여 건이라 사실상 전부 손에
있습니다. 실제로 반응 0 인 게시글이 반응 6 인 글을 제치고 1위로 오는 것까지 확인했습니다.)

---

## 요청 — `sort=recommended` 에 "보는 사람의 방문 조건"을 받아 1순위 키로

### 파라미터

| | |
|---|---|
| 이름 | **`myVisitorTags`** (쉼표 구분) |
| 값 | `visit_wheelchair`, `visit_visual`, `visit_hearing`, `visit_infant`, `visit_elderly` 중 0~5개 |
| 예 | `GET /v1/reviews?sort=recommended&limit=5&myVisitorTags=visit_visual` |
| 없으면 | 지금과 **완전히 동일**하게 동작 (기본값 없음) |
| 모르는 코드 | 400 이 아니라 **그냥 0점**. 기존 `visitorTag` 필터와 같은 규칙 |

이름을 `visitorTag`(단수, 기존 필터)와 **다르게** 둔 이유: 그것은 "이 조건인 후기만 보기"라는
**걸러내기**이고, 이것은 "위로 올리기"입니다. 이름이 비슷하면 나중에 둘이 섞입니다.

`sort=latest` 에는 **적용하지 않습니다** — "최신"이 최신이 아니면 거짓말입니다.

### ORDER BY

`src/server/app.ts:934` 의 `recommended` 앞에 키 하나를 더합니다.

```
(보는 사람의 방문 조건과 겹치는 태그 수) desc,
(r.like_count + r.comment_count) desc,
r.created_at desc
```

```ts
const myTags = (c.req.query('myVisitorTags') ?? '')
  .split(',').map((s) => s.trim()).filter(Boolean).slice(0, 5);

let order = REVIEW_ORDERS[sort] ?? REVIEW_ORDERS.recommended;

// ⚠️ count 쿼리와 rows 쿼리가 filters 를 함께 쓰므로 배열을 나눈다 (아래 함정 참고)
const rowParams = [...filters];
if (sort !== 'latest' && myTags.length) {
  rowParams.push(myTags);
  order = `(select count(*) from review_tags rt
              join review_tag_defs d on d.code = rt.tag_code
             where rt.review_id = r.id
               and d.kind = 'visitor'
               and rt.tag_code = any($${rowParams.length}::text[])) desc, ${order}`;
}

const rows = (await query<ReviewRow>(
  `${reviewSelect(viewerParam)} ${wsql} order by ${order} limit ${limit} offset ${offset}`,
  rowParams,   // ← filters 가 아니라 rowParams
)).rows;
```

**⚠️ 함정 — `filters` 에 그냥 push 하면 `total` 쿼리가 깨집니다.**
바로 위 `select count(*) ... ${wsql}` 이 같은 `filters` 를 씁니다. 거기엔 `$N` 이 등장하지
않으므로 파라미터 개수가 어긋나 `bind message supplies N parameters, but prepared statement
requires M` 이 납니다. 그래서 **rows 쿼리용 배열을 따로** 떠서 씁니다. `total` 은 정렬과
무관하므로 그대로 두시면 됩니다.

`d.kind = 'visitor'` 를 조건에 남겨 주세요 — place 태그 코드를 넣어도 점수가 오르지 않게
하는 잠금입니다.

### 확인 방법

```bash
# 지금(파라미터 없음): id=15 가 6위 → limit=5 면 안 나온다
curl -sH "Authorization: Bearer $KEY" \
  "$BASE/v1/reviews?sort=recommended&limit=5" | jq '[.items[].id]'
# → [2,3,4,1,6]

# 요청 후: id=15 가 반응 0 인데도 1위
curl -sH "Authorization: Bearer $KEY" \
  "$BASE/v1/reviews?sort=recommended&limit=5&myVisitorTags=visit_visual" | jq '[.items[].id]'
# → [15,2,3,4,1]   ← 이렇게 되면 됩니다

# 최신순은 영향을 받지 않아야 한다
curl -sH "Authorization: Bearer $KEY" \
  "$BASE/v1/reviews?sort=latest&limit=5&myVisitorTags=visit_visual" | jq '[.items[].id]'
# → 지금과 동일
```

---

## 왜 `visitor` 태그만 세는지 (place 태그는 안 씁니다)

접근성과 관련된 place 태그가 셋 있습니다 — `barrier_free`(무장애 친화적이에요),
`silver`(어르신과 함께하기 좋아요), `kids`(아이와 함께하기 좋아요). 이것도 세어야 할 것 같지만
**두 태그가 다른 것을 묻습니다**:

- `visit_wheelchair` — **쓴 사람이** 휠체어를 씁니다 → "나와 같은 조건의 사람이 남긴 후기"
- `barrier_free` — **그 장소가** 무장애 친화적입니다 → 장소 평가

앱이 원하는 것은 앞의 것입니다. 데이터로도 그렇습니다 — **`barrier_free` 가 12건 중 5건**에
붙어 있어서, 휠체어 축을 고른 사람에게는 상위 5건이 전부 "일치"가 되어 **순서가 지금과
똑같아집니다.** 반면 방문 조건 태그는 희소해서 실제로 위로 올라옵니다.

나중에 섞고 싶어지면 visitor 를 2점, place 를 1점으로 두는 식이 될 것 같습니다. 지금은
단순하게 갑니다.

## 앱과 서버가 같은 공식을 씁니다 (충돌 없음)

홈은 후기와 게시글을 **한 섹션에 섞어** 그립니다. `/v1/posts` 에는 정렬 파라미터가 아예
없어서(항상 `created_at desc`) 앱이 합치는 자리에서 규칙을 다시 적용해야 합니다. 그 규칙을
위와 **똑같이** 맞춰 두었으니 서버 순서와 싸우지 않습니다.

## 민감정보 — 이 파라미터를 접속 로그에서 빼 주세요

무장애 축은 민감정보입니다(개인정보처리방침에서 별도 동의를 받는 항목). 참고로 지금도 홈이
추천 장소를 받을 때 `access=<groups>` 를 쿼리로 보내고 있어서 **새로운 종류의 전송은
아닙니다.** 다만 쿼리스트링은 접속 로그에 그대로 남으므로, `myVisitorTags` 와 `access` 를
**로그에서 마스킹**해 주시면 좋겠습니다. 헤더로 받는 편이 낫다고 판단하시면 그쪽도 좋습니다 —
앱은 어느 쪽이든 한 줄입니다.

---

## 곁들여 — `GET /v1/reviews` 항목의 태그에 `kind` 가 없습니다 (작은 것)

`reviewSelect`(app.ts:891)가 태그를 `code`·`label`·`shortLabel`·`icon` 만 실어 줍니다.
`kind` 는 정의 목록 `GET /v1/review-tags` 에만 있습니다.

앱이 처음에 `kind == 'visitor'` 로 방문 조건 태그를 가르려다 **하나도 걸리지 않는 것**을
실측으로 발견했습니다. 지금은 코드(`visit_*`)로 되찾아 쓰고 있어 **막혀 있지는 않습니다.**
다만 `json_build_object` 에 `'kind', d.kind` 한 줄이면 되는 일이고, 다른 화면이 같은 함정에
빠지지 않게 실어 주시면 좋겠습니다.

## 나중에 — 게시글도 쌓이면 같은 것이 필요합니다

지금은 게시글이 10여 건이라 앱이 전부 손에 쥐고 다시 세울 수 있습니다. 한 페이지를 넘기기
시작하면 후기와 똑같은 문제가 생깁니다. `/v1/posts` 에는 `sort` 가 아예 없으니, 그때
`sort=recommended` + `myVisitorTags` 를 함께 여는 것이 자연스러울 것 같습니다.
**지금 해 달라는 것은 아닙니다** — 설계할 때 염두에만 두시면 됩니다.
