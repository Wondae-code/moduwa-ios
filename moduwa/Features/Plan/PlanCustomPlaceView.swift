import SwiftUI

/// 검색에 없는 곳을 직접 만들어 담기 — "나만의 장소"(트리플 스샷 519:1178 의 2·3단계).
///
/// **모두와 자체 시안 없음.** 디자이너가 붙여 둔 트리플 스크린샷이 유일한 지시이고,
/// 거기서 옮긴 것은 ①지도를 움직여 위치 고르기 ②이름 ③카테고리 세 가지다.
///
/// 트리플에 있지만 **옮기지 않은 것 둘**:
///  - **주소 표시**: 좌표를 주소로 바꾸려면 역지오코딩이 필요한데, 우리 일정 화면은 나만의 장소를
///    "숙소 · 나만의 장소"로 그린다(시안 519:775, `PlanPlace.subtitle`). 저장에도 표시에도 안 쓰인다.
///  - **"나만의 장소 저장"(다른 여행에서 재사용)**: 서버에 그 저장소가 없다. 체크박스만 두면 거짓말이 된다.
struct PlanCustomPlaceView: View {
    /// 지도를 처음 띄울 자리 — 플랜의 여행 지역.
    let initialCamera: RegionMapCamera
    /// 완성된 장소를 호출부에 넘긴다. 저장은 담기 화면이 모아서 한다.
    var onCreate: (PlanPlace) -> Void

    @Environment(\.dismiss) private var dismiss

    /// 지도가 멈출 때마다 갱신되는 화면 한가운데 좌표.
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var name = ""
    @State private var category: PlaceCategory?
    @State private var step: Step = .location
    /// 카카오맵 엔진은 레이아웃이 잡힌 뒤에 켜야 한다 — 미리 켜면 렌더링이 멈춘다.
    @State private var mapDrawn = false
    @FocusState private var isNameFocused: Bool

    /// 트리플과 같은 두 단계. 한 화면에 지도와 입력을 함께 두면 지도가 반쪽이 되어
    /// 위치를 정밀하게 맞추기 어렵다.
    private enum Step { case location, detail }

    /// 트리플의 라디오는 관광지·맛집·숙소·선택 안 함이다. 앞 셋은 `PlaceCategory`에 그대로 있고
    /// "선택 안 함"은 nil 이다 — 축제·공연·전시는 사용자가 직접 만들 일이 드물어 뺐다.
    private static let choices: [PlaceCategory] = [.attraction, .food, .stay]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .location: locationStep
            case .detail: detailStep
            }
        }
        .background(.white)
        .navigationTitle(step == .location ? "지도에서 위치 선택" : "나만의 장소 추가")
        .navigationBarTitleDisplayMode(.inline)
        // 이 화면은 **전체 화면으로 덮여 올라온다**(`PlanPlaceAddView` 참고) — 화면 대부분이
        //  지도라, 시트 안에 두면 지도를 끄는 동작을 시트의 끌어 닫기·스와이프 뒤로가기가 가로챈다.
        //  덮기에는 그 두 제스처가 없으므로 닫는 길은 여기 왼쪽 버튼 하나뿐이다.
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
                .accessibilityLabel(step == .detail ? "위치 다시 고르기" : "뒤로")
            }
        }
    }

    /// 2단계에서는 화면을 나가는 대신 **지도로 되돌아간다** — 이름까지 적어 놓고 위치만 고치고 싶을 때
    /// 화면을 통째로 나갔다 다시 들어오면 찍어 둔 자리를 처음부터 다시 맞춰야 한다.
    /// 고른 좌표와 적어 둔 이름은 그대로 남는다(둘 다 이 화면의 상태다).
    private func goBack() {
        if step == .detail { step = .location } else { dismiss() }
    }

    // MARK: - 1단계: 위치

    private var locationStep: some View {
        VStack(spacing: 0) {
            Text("화면을 움직이거나 확대·축소해 보세요")
                .font(.notoSans(14))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.photoPlaceholder)

            ZStack {
                PlanLocationPickerMap(
                    initialCamera: initialCamera,
                    onCenterChanged: { latitude = $0; longitude = $1 },
                    draw: $mapDrawn
                )
                .onAppear { mapDrawn = true }
                .onDisappear { mapDrawn = false }

                // 핀은 화면 한가운데 고정 — 지도가 그 밑에서 움직인다.
                LocationPickerPin()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                step = .detail
                isNameFocused = true
            } label: {
                Text("확인")
                    .font(.notoSans(16, .bold))
                    .foregroundStyle(latitude == nil ? Color.textSecondary : Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(Capsule().fill(
                        latitude == nil ? Color.photoPlaceholder : Color.moduwaGreen
                    ))
            }
            .buttonStyle(.plain)
            // 좌표를 아직 못 읽었다면 지도가 준비되지 않은 것이다.
            .disabled(latitude == nil)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .accessibilityLabel("이 위치로 정하기")
        }
    }

    // MARK: - 2단계: 이름·카테고리

    private var detailStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    field("장소명")
                    TextField("장소명을 입력해 주세요", text: $name)
                        .font(.notoSans(15))
                        .foregroundStyle(Color.textPrimary)
                        .tint(.deepGreen)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: Radius.card)
                            .fill(Color.photoPlaceholder))
                        .accessibilityLabel("장소명")

                    field("카테고리")
                        .padding(.top, 24)

                    VStack(spacing: 0) {
                        ForEach(Self.choices) { choice in
                            categoryRow(label: choice.rawValue, isSelected: category == choice) {
                                withoutAnimation { category = choice }
                            }
                        }
                        categoryRow(label: "선택 안 함", isSelected: category == nil) {
                            withoutAnimation { category = nil }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Radius.card)
                        .fill(Color.photoPlaceholder))

                    Text("일정에는 “\(category?.rawValue ?? "나만의 장소") · 나만의 장소”로 표시돼요")
                        .font(.notoSans(13))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 8) {
                if trimmedName.isEmpty {
                    Text("장소명을 입력해 주세요")
                        .font(.notoSans(13))
                        .foregroundStyle(Color.textSecondary)
                }

                Button(action: create) {
                    Text("완료")
                        .font(.notoSans(16, .bold))
                        .foregroundStyle(trimmedName.isEmpty ? Color.textSecondary : Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Capsule().fill(
                            trimmedName.isEmpty ? Color.photoPlaceholder : Color.moduwaGreen
                        ))
                        .shadow(color: Color(hex: 0x9ACA10).opacity(trimmedName.isEmpty ? 0 : 0.3),
                                radius: 7, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(trimmedName.isEmpty)
                .accessibilityLabel("나만의 장소 만들기")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.white)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.cardStroke).frame(height: 1)
            }
        }
    }

    private func field(_ title: String) -> some View {
        Text(title)
            .font(.notoSans(16, .bold, relativeTo: .headline))
            .tracking(-0.4)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }

    /// 트리플의 라디오. 선택을 색만으로 전달하지 않도록 채워진 원/빈 원이 형태로 함께 알린다.
    private func categoryRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.notoSans(15, isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.deepGreen : Color.iconGray)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        onCreate(PlanPlace(
            // contentID 가 nil 이라는 것이 곧 "나만의 장소"다 — 라임 번호 뱃지와
            // 리뷰 버튼 없음이 여기서 갈린다(`PlanPlace.isCustom`).
            contentID: nil,
            name: trimmedName,
            categoryLabel: category?.rawValue ?? "나만의 장소",
            // region 은 비워 둔다. 화면이 "나만의 장소"로 대신 채운다(`PlanPlace.subtitle`).
            region: nil,
            category: category,
            imageURL: nil,
            latitude: latitude,
            longitude: longitude
        ))
        dismiss()
    }
}

// MARK: - 핀

/// 위치 선택 지도 한가운데 고정되는 핀.
///
/// `Image(systemName: "mappin")` 을 쓰지 않는다 — 시스템 핀은 **어느 픽셀이 고른 지점인지**
/// 알려 주지 않는다(글리프 안에서 뾰족한 끝의 위치가 폰트마다 다르고, 여백도 들어 있다).
/// 지도를 밀어 좌표를 맞추는 화면에서 그 애매함은 곧 잘못 찍힌 장소가 된다.
///
/// 그래서 세 조각으로 나눠 그린다 — **머리 · 대 · 바닥점**.
///  바닥의 작은 타원이 실제로 고른 좌표이고, 대가 머리와 그 점을 잇는다.
///  머리만 있으면 "이 근처"가 되지만, 바닥점이 있으면 "바로 여기"가 된다.
///
/// 색은 딥그린이다. 담기고 나면 라임 번호 뱃지가 되지만(`PlanNumberBadge` — 나만의 장소는 라임),
/// 라임(#A7E100)은 밝은 지도 위에서 대비가 모자라 **찍는 동안에는 읽히지 않는다.**
/// 대신 머리 한가운데에 라임 점을 박아 "이건 나만의 장소가 된다"는 연결을 남긴다.
private struct LocationPickerPin: View {
    private static let headSize: CGFloat = 34
    private static let stalkHeight: CGFloat = 14
    private static let footHeight: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.deepGreen)
                Circle().strokeBorder(.white, lineWidth: 2.5)
                Circle().fill(Color.moduwaGreen).frame(width: 10, height: 10)
            }
            .frame(width: Self.headSize, height: Self.headSize)
            // 지도 위에 떠 있다는 인상을 준다 — 배경이 어떤 색이든 머리가 묻히지 않는다.
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            Rectangle()
                .fill(Color.deepGreen)
                .frame(width: 2.5, height: Self.stalkHeight)

            // 고른 좌표 그 자체. 지도에 닿아 있는 유일한 부분이라 그림자를 주지 않는다.
            Ellipse()
                .fill(.black.opacity(0.22))
                .frame(width: 10, height: Self.footHeight)
        }
        // ⚠️ 뷰의 한가운데가 아니라 **바닥점의 한가운데**가 화면 중심에 와야 한다.
        //  지도가 좌표를 읽는 자리(`PlanLocationPickerMap.reportCenter`)가 화면 중심이기 때문이다.
        //  그대로 두면 핀이 가리키는 곳보다 한참 위가 저장된다.
        .offset(y: -(totalHeight / 2 - Self.footHeight / 2))
    }

    private var totalHeight: CGFloat {
        Self.headSize + Self.stalkHeight + Self.footHeight
    }
}

#Preview("핀") {
    Color.photoPlaceholder
        .overlay { LocationPickerPin() }
        .overlay {
            // 화면 중심 — 핀의 바닥점이 여기에 정확히 얹혀야 한다.
            Rectangle().fill(.red.opacity(0.6)).frame(height: 1)
        }
        .frame(height: 240)
}

#Preview("나만의 장소") {
    NavigationStack {
        PlanCustomPlaceView(initialCamera: TravelRegion.gyeongju.mapCamera) { _ in }
    }
}
