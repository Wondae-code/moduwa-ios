// moduwa-backend PostgreSQL에서 홈 피드 데이터를 조합해 iOS 번들용 JSON을 생성한다.
import { createRequire } from 'module';
import { writeFileSync } from 'fs';
const require = createRequire('/Users/wondae/Projects/moduwa-backend/package.json');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: 'postgresql://moduwa:moduwa@localhost:5432/moduwa' });

// content_type_id ↔ 앱 카테고리
const CATEGORIES = [
  { key: 'stay', contentTypeId: '32' },
  { key: 'food', contentTypeId: '39' },
  { key: 'attraction', contentTypeId: '12' },
  { key: 'festival', contentTypeId: '15' },
];

// 시도명 축약 (디자인 표기: "제주 서귀포시")
const PROVINCE_SHORT = {
  서울특별시: '서울', 부산광역시: '부산', 대구광역시: '대구', 인천광역시: '인천',
  광주광역시: '광주', 대전광역시: '대전', 울산광역시: '울산', 세종특별자치시: '세종',
  경기도: '경기', 강원특별자치도: '강원', 충청북도: '충북', 충청남도: '충남',
  전북특별자치도: '전북', 전라남도: '전남', 경상북도: '경북', 경상남도: '경남',
  제주특별자치도: '제주',
};

// 2026 행정구역 개편 통합시: 광주 자치구는 '광주', 나머지는 '전남'
const GWANGJU_DISTRICTS = new Set(['동구', '서구', '남구', '북구', '광산구']);

function shortRegion(addr1) {
  const [province = '', district = ''] = (addr1 ?? '').trim().split(/\s+/);
  let short = PROVINCE_SHORT[province];
  if (!short && province === '전남광주통합특별시') {
    short = GWANGJU_DISTRICTS.has(district) ? '광주' : '전남';
  }
  return [short ?? province, district].filter(Boolean).join(' ');
}

// 접근성 원문 정리: 꼬리표 제거, 첫 줄만, 공백 정리, 40자 컷
function cleanNote(text) {
  if (!text) return null;
  let t = text.split(/\r?\n/)[0]
    .replace(/_[^_]*편의시설\s*$/, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (t.length > 40) t = t.slice(0, 39) + '…';
  return t.length ? t : null;
}

// 뱃지 결정 우선순위: 휠체어 > 무장애 객실(숙소) > 평탄 동선(접근로)
function pickFeature(row, categoryKey) {
  const wheelchair = cleanNote(row.wheelchair);
  const room = cleanNote(row.room);
  const route = cleanNote(row.route);
  const elevator = cleanNote(row.elevator);
  const restroom = cleanNote(row.restroom);

  if (wheelchair) {
    // "대여가능" 같이 맥락 없는 문구는 앞에 휠체어를 붙여준다
    const note = /휠체어/.test(wheelchair) ? wheelchair : `휠체어 ${wheelchair}`;
    return { feature: 'wheelchairAccessible', note };
  }
  if (categoryKey === 'stay' && room) return { feature: 'barrierFreeRoom', note: room };
  if (route) return { feature: 'flatPath', note: route };
  if (elevator) return { feature: 'flatPath', note: /엘리베이터/.test(elevator) ? elevator : `엘리베이터 ${elevator}` };
  if (restroom) return { feature: 'flatPath', note: restroom };
  if (room) return { feature: 'barrierFreeRoom', note: room };
  return null;
}

const QUERY = `
SELECT p.content_id, p.title, p.addr1, p.firstimage,
       d.wheelchair, d.room, d.route, d.elevator, d.restroom
FROM kor_poi p
JOIN kor_with_detail d ON d.content_id = p.content_id
WHERE p.service = 'korwith'
  AND p.content_type_id = $1
  AND coalesce(p.firstimage, '') <> ''
  AND (nullif(trim(d.wheelchair),'') IS NOT NULL
    OR nullif(trim(d.route),'') IS NOT NULL
    OR nullif(trim(d.room),'') IS NOT NULL
    OR nullif(trim(d.elevator),'') IS NOT NULL
    OR nullif(trim(d.restroom),'') IS NOT NULL)
ORDER BY (nullif(trim(d.wheelchair),'') IS NOT NULL)::int
       + (nullif(trim(d.room),'') IS NOT NULL)::int
       + (nullif(trim(d.route),'') IS NOT NULL)::int
       + (nullif(trim(d.elevator),'') IS NOT NULL)::int
       + (nullif(trim(d.restroom),'') IS NOT NULL)::int DESC,
       p.modified_time DESC
LIMIT 8`;

const placesByCategory = {};
for (const { key, contentTypeId } of CATEGORIES) {
  const { rows } = await pool.query(QUERY, [contentTypeId]);
  placesByCategory[key] = rows.flatMap((row) => {
    const picked = pickFeature(row, key);
    if (!picked) return [];
    return [{
      id: row.content_id,
      name: row.title.trim(),
      region: shortRegion(row.addr1),
      imageURL: row.firstimage.replace(/^http:\/\//, 'https://'),
      accessibilityNote: picked.note,
      feature: picked.feature,
    }];
  }).slice(0, 6);
}

const feed = {
  hero: {
    userName: '모두와',
    headline: '휠체어로 이동하기 좋은 코스를 추천드려요',
    caption: '같은 태그의 여행자들이 추천한 코스예요',
    tags: ['#경사로', '#휠체어', '#효도여행'],
  },
  placesByCategory,
};

writeFileSync('/Users/wondae/Projects/moduwa-ios/moduwa/Resources/HomeFeed.json', JSON.stringify(feed, null, 2));
console.log('written. counts:', Object.fromEntries(Object.entries(placesByCategory).map(([k, v]) => [k, v.length])));
await pool.end();
