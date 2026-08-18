import SwiftUI

// 장소 검색 화면(`SearchView`, Figma "모두와 UI — 서브 > 검색")의 구성 요소를 공용으로 뺀 것.
//
// 플랜의 "장소 추가"(`PlanPlaceAddView`)가 같은 모습이어야 한다는 요구(2026-08-16)에서 나왔다.
// 눈으로 맞추는 대신 **같은 뷰를 쓰게** 한다 — 값을 베껴 두면 한쪽 시안이 바뀔 때 반드시 어긋난다.
//
// 두 화면이 다른 것은 행의 오른쪽 끝뿐이다(상세로 가는 chevron ↔ 담을지 고르는 체크).
// 그래서 행만 accessory 를 받고 나머지는 통째로 공유한다.

// MARK: - 검색 입력

/// 시안의 캡슐 검색창 — 40pt, 좌측 돋보기, 입력이 있으면 우측 지우기.
struct PlaceSearchField: View {
    @Binding var query: String
    var placeholder: String = "장소, 지역으로 검색"
    /// 포커스는 호출부가 들고 있는다 — 화면마다 언제 키보드를 올릴지가 다르다.
    var focus: FocusState<Bool>.Binding
    var onSubmit: () -> Void
    /// 지우기를 눌렀을 때. 검색 상태를 되돌리는 일은 화면마다 달라 호출부에 맡긴다.
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image("search")
                .renderingMode(.template)
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $query)
                .font(.notoSans(15))
                .foregroundStyle(.textPrimary)
                .tint(.deepGreen)
                .focused(focus)
                .submitLabel(.search)
                .onSubmit(onSubmit)

            if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.iconGray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("입력 지우기")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Capsule().fill(Color.photoPlaceholder))
    }
}

// MARK: - 결과 행

/// 시안 "검색 — 결과"의 56pt 썸네일 행.
///
/// 오른쪽 끝만 호출부가 정한다 — 검색 화면은 chevron, 플랜 담기는 체크다.
struct PlaceSearchRow<Accessory: View>: View {
    let place: Place
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: Spacing.m) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(place.name)
                        .font(.cardTitle)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)

                    accessibilityBadge
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(place.region) · \(place.categoryLabel ?? place.category.rawValue)")
                    .font(.meta13)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }

            accessory
        }
        .padding(.vertical, Spacing.m)
        .contentShape(Rectangle())
    }

    /// 사진이 없는 장소가 5곳 중 1곳이라(`PlaceCard` 주석 참고) 빈 회색 칸이 흔하다.
    /// 목록 행은 56pt로 작아 카테고리 아이콘을 넣으면 오히려 지저분해져 회색으로 둔다.
    private var thumbnail: some View {
        Color.photoPlaceholder
            .frame(width: 56, height: 56)
            .overlay {
                if let imageURL = place.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.photoPlaceholder
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    private var accessibilityBadge: some View {
        Circle()
            .fill(Color.deepGreen)
            .frame(width: 20, height: 20)
            .overlay {
                Image("access_wheelchair")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: AccessibilityFeature.wheelchairAccessible.iconSize(height: 14).width,
                        height: 14
                    )
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }

    /// 두 화면이 같은 문장을 읽어 주도록 여기서 만든다.
    var accessibilityText: String {
        "\(place.name), \(place.region), \(place.categoryLabel ?? place.category.rawValue)"
    }
}

// MARK: - 빈 상태 · 실패 상태

/// 96pt 회색 원 안에 돋보기를 넣은 안내. 검색 결과 없음·실패가 같은 형태를 쓴다.
struct PlaceSearchMessage: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.photoPlaceholder)
                .frame(width: 96, height: 96)
                .overlay {
                    Image("search")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.iconGray)
                }
            Text(title)
                .font(.notoSans(18, .bold))
                .foregroundStyle(.textPrimary)
                .padding(.top, 4)
            Text(subtitle)
                .font(.notoSans(14))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// 검색 중. 두 화면이 같은 문구를 쓴다.
struct PlaceSearchLoading: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView().tint(.deepGreen)
            Text("검색 결과를 불러오는 중이에요")
                .font(.notoSans(18, .bold))
                .foregroundStyle(.textPrimary)
                .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("검색 결과를 불러오는 중이에요")
    }
}

// MARK: - 최근 검색어

/// 최근 검색어 저장소 — **두 화면이 같은 목록을 본다.**
/// 홈에서 찾은 것과 일정에 담으려고 찾은 것은 사용자에겐 같은 "최근에 찾은 장소"다.
enum RecentSearchStore {
    static let key = "recentSearches"
    static let limit = 10

    static func decode(_ data: Data) -> [String] {
        (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    static func encode(_ items: [String]) -> Data {
        (try? JSONEncoder().encode(items)) ?? Data()
    }

    /// 새 검색어를 맨 앞에 올리고 중복을 걷어낸다.
    static func adding(_ term: String, to items: [String]) -> [String] {
        Array(([term] + items.filter { $0 != term }).prefix(limit))
    }
}

/// 최근 검색어 칩 — 삭제 버튼 포함, 줄바꿈 플로우 배치.
struct RecentSearchChips: View {
    let items: [String]
    let onTap: (String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(items, id: \.self) { term in
                HStack(spacing: 6) {
                    Button { onTap(term) } label: {
                        Text(term)
                            .font(.notoSans(14))
                            .foregroundStyle(.textSecondary)
                    }
                    Button { onDelete(term) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.iconGray)
                    }
                    .accessibilityLabel("\(term) 삭제")
                }
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .padding(.vertical, 8)
                .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
            }
        }
    }
}

// MARK: - 결과 목록

/// 검색 결과 목록 — 머리글("검색 결과 N") + 행 + 구분선 + "더 불러오기".
///
/// 세 화면(`SearchView`·`PlanPlaceAddView`·`PostPlacePickerView`)이 이 목록을 **똑같이**
/// 그리고 있었다. 행 오른쪽 장식과 눌렀을 때의 동작만 달라서, 그 부분만 `row` 로 받는다.
///
/// 더 불러오기를 여기 둔 이유: 목록을 그리는 곳과 다음 페이지를 잇는 곳이 갈라지면
/// 한 화면만 고치고 나머지를 잊는다(실제로 세 화면 모두 첫 20개에 멈춰 있었다).
struct PlaceSearchResultList<Row: View>: View {
    let paginator: PlaceSearchPaginator
    /// 다음 페이지를 요청한다. 서비스는 화면이 `@Environment` 로 들고 있어 넘겨받는다.
    let onLoadMore: () -> Void
    @ViewBuilder let row: (Place) -> Row

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("검색 결과 \(paginator.total)")
                    .font(.meta13)
                    .foregroundStyle(.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                LazyVStack(spacing: 0) {
                    ForEach(Array(paginator.places.enumerated()), id: \.element.id) { index, place in
                        row(place)

                        // 마지막 행 뒤에는 선을 긋지 않는다.
                        if index < paginator.places.count - 1 {
                            Rectangle()
                                .fill(Color.photoPlaceholder)
                                .frame(height: 1)
                        }
                    }
                }

                if paginator.hasMore {
                    moreFooter
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.xl)
        }
    }

    /// 세 상태를 한 자리에서 보여 준다 — 받는 중 / 실패(다시) / 더 있음.
    /// 실패해도 이미 받은 목록은 지우지 않는다(`loadMoreFailed` 주석 참고).
    @ViewBuilder
    private var moreFooter: some View {
        let remaining = max(0, paginator.total - paginator.places.count)

        if paginator.isLoadingMore {
            HStack(spacing: 8) {
                ProgressView().tint(.deepGreen)
                Text("더 불러오는 중이에요")
                    .font(.notoSans(14))
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("더 불러오는 중이에요")
        } else if paginator.loadMoreFailed {
            VStack(spacing: 8) {
                Text("더 불러오지 못했어요")
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                LoadMoreButton(title: "다시 시도", action: onLoadMore)
            }
            .padding(.top, 14)
        } else {
            // 남은 수를 적어 둔다 — 몇 번 더 눌러야 하는지 가늠이 된다.
            LoadMoreButton(title: "검색 결과 더보기 (\(remaining))", action: onLoadMore)
                .padding(.top, 14)
                .accessibilityLabel("검색 결과 더보기, \(remaining)곳 남음")
        }
    }
}
