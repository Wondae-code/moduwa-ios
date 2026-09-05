import SwiftUI

/// 온보딩을 끝낸 사람이 어디로 가고 싶다고 했는지 (시안 868:777 의 버튼 두 개).
enum OnboardingOutcome {
    /// "둘러보기" — 홈에 그대로 둔다.
    case browse
    /// "여행계획 짜러가기" — 플랜 탭으로 보낸다.
    case planTrip
}

/// 첫 실행 온보딩 — 3장 (시안 "모두와 UI — 온보딩, 로그인" 868:150).
///
/// 1. 모두와 소개 (868:787)
/// 2. 무장애정보입력 (868:281 / 868:317) — "완료했어요"
/// 3. 환영 + 갈 곳 고르기 (868:777) — "둘러보기" / "여행계획 짜러가기"
///
/// 여기서 고른 값은 **기기에 저장되고, 가입할 때 계정으로 올라간다**
/// (`OnboardingProfileStore` → `POST /v1/auth/email/sign-up`). 가입 전에는 서버에 아무것도
/// 만들지 않는다 — 그래서 "가입했더니 내 것이 사라졌다"가 생기지 않는다.
///
/// **가입을 요구하지 않는다.** 앱의 가치를 확인하기 전에 계정 벽을 만나면 대부분 떠나고,
/// 계정과 무관한 기능(무장애 장소 찾기)에 로그인을 강제하면 앱스토어 심사에서도 걸린다.
/// 로그인은 글을 쓰거나 저장할 때 처음 묻는다(디자이너 메모 "*로그인이 필요한 기능:
/// 리뷰/게시글/플랜(작성기능)" 과 같은 결론이다).
///
/// **스킵 버튼이 없다.** 예전 판의 "나중에 고를래요"는 디자이너가 지웠고
/// (868:850 "'괜찮아요'와 같은 스킵 버튼을 제거"), 대신 2장에 **"해당없음"** 항목이 들어왔다 —
/// 건너뛰는 길을 없앤 것이 아니라 **답으로 만든 것**이다.
struct OnboardingView: View {
    /// 온보딩을 마쳤다(고른 것이 없어도 마친 것이다).
    var onFinish: (OnboardingOutcome) -> Void

    private enum Page: Int, Hashable, CaseIterable { case intro, access, welcome }

    @State private var page: Page = .intro
    @State private var selection: Set<AccessibilityFeature> =
        Set(OnboardingProfileStore.shared.features)
    /// "해당없음" 을 눌렀는지. 빈 `selection` 과 **다른 뜻이다** —
    /// 아직 아무것도 안 누른 상태에서 해당없음이 켜져 보이면 답을 대신 정해 준 셈이 된다.
    @State private var choseNone = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                intro.tag(Page.intro)
                access.tag(Page.access)
                welcome.tag(Page.welcome)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.bottom, 20)
        }
        .background(.white)
    }

    // MARK: - 1. 소개

    private var intro: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 32) {
                Text("안녕하세요")
                    .font(.notoSans(20, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                Text("나이, 장애에 상관없이, 누구와 함께하든,\n모두의 즐거운 여행을 바라는 모두와에요.")
                    .font(.notoSans(20, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(.textSecondary)
                    // 시안 lineHeight 32 (20pt 본문). 12 는 그보다 9pt 성겼다.
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 60)

            Spacer(minLength: 24)

            Image("onboarding_welcome")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 347)   // 시안 1037:211 — 344×347
                .accessibilityHidden(true)

            Spacer(minLength: 24)
        }
    }

    // MARK: - 2. 무장애정보입력

    private var access: some View {
        OnboardingPage(stepLabel: "무장애정보입력") {
            VStack(alignment: .leading, spacing: 8) {
                Text("계획에 앞서, 여행자님을 위해\n저희가 배려할 요소가 있다면 알려주세요")
                    .font(.notoSans(20, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(.textSecondary)
                    // 시안 lineHeight 32 (20pt 본문). 12 는 그보다 9pt 성겼다.
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text("*개인설정에서 수정가능")
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .tracking(-0.4)
                    .foregroundStyle(.deepGreen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 44)

            Spacer(minLength: 24)

            // 시안 실측: 라벨 아래 31.5 만큼 띄우고 다음 줄이 온다(24 는 좁았다).
            VStack(spacing: 31.5) {
                HStack(spacing: 20) {
                    ForEach(Self.firstRow, id: \.self) { circle($0) }
                }
                HStack(spacing: 20) {
                    ForEach(Self.secondRow, id: \.self) { circle($0) }
                    AccessibilityNoneButton(isOn: choseNone) {
                        selection.removeAll()
                        choseNone.toggle()
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 24)

            // 시안은 **아무것도 고르지 않으면 비활성**이다(회색 #E6E6E6 + 글자 #B3B3B3).
            //  디자이너가 스킵 버튼을 지우고 "해당없음" 을 답으로 만든 것과 이어진다 —
            //  건너뛰는 길을 없앤 것이 아니라 답으로 바꾼 것이라, 답을 하나는 받는다.
            AuthPrimaryButton(title: "완료했어요", isEnabled: hasAnswered, shape: .capsule) {
                page = .welcome
            }
            .padding(.bottom, 20)
        }
    }

    /// 무장애정보입력에 답했는가. "해당없음" 도 답이다 — 그래서 빈 선택과 구분해서 센다.
    private var hasAnswered: Bool { !selection.isEmpty || choseNone }

    /// 사람이 직접 고르는 축 — 브랜드 가이드 아이콘 5종.
    /// `flatPath`·`barrierFreeRoom` 은 서버 속성에서 파생되는 표시용 값이라 여기 없다.
    private static let firstRow: [AccessibilityFeature] =
        [.wheelchairAccessible, .visuallyImpairedFriendly, .hearingFriendly]
    private static let secondRow: [AccessibilityFeature] = [.elderlyFriendly, .childFriendly]

    private func circle(_ feature: AccessibilityFeature) -> some View {
        AccessibilityCircleButton(feature: feature, isOn: selection.contains(feature)) {
            // 하나라도 고르면 "해당없음" 은 더 이상 사실이 아니다.
            choseNone = false
            if selection.contains(feature) {
                selection.remove(feature)
            } else {
                selection.insert(feature)
            }
        }
    }

    // MARK: - 3. 환영

    private var welcome: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 32) {
                Text("모두와에 오신 것을 환영합니다!")
                    .font(.notoSans(20, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                Text("다양한 정보들을 둘러보며\n여행계획을 세워보세요.")
                    .font(.notoSans(20, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(.textSecondary)
                    // 시안 lineHeight 32 (20pt 본문). 12 는 그보다 9pt 성겼다.
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 76)

            Spacer(minLength: 24)

            Image("onboarding_landmark")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)   // 시안 1037:212 — 300×300
                .accessibilityHidden(true)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                AuthSecondaryButton(title: "둘러보기") { finish(.browse) }
                AuthPrimaryButton(title: "여행계획 짜러가기", shape: .capsule) { finish(.planTrip) }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - 페이지 표시

    /// 시안의 Page control. 시스템 점(`indexDisplayMode: .always`)은 색을 브랜드 값으로
    /// 맞추기 어렵고 Dynamic Type 을 따르지 않아 직접 그린다.
    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(Page.allCases, id: \.self) { item in
                // 시안: 지금 장은 딥그린으로 **채우고**, 나머지는 흰 원에 딥그린 **테두리** 1pt.
                //  회색 채움으로 두면 지나온 장과 남은 장이 배경에 묻힌다.
                Circle()
                    .fill(item == page ? Color.deepGreen : .white)
                    .overlay(Circle().stroke(Color.deepGreen, lineWidth: item == page ? 0 : 1))
                    .frame(width: 8, height: 8)
            }
        }
        // iOS 페이지 컨트롤의 기본 읽기 방식("페이지, 1/3")을 따른다 —
        //  "3장 중 1장" 처럼 우리끼리 만든 셈법은 다른 앱에서 배운 것과 어긋난다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("페이지")
        .accessibilityValue("\(page.rawValue + 1)/\(Page.allCases.count)")
    }

    private func finish(_ outcome: OnboardingOutcome) {
        // 고른 것이 없어도 완료로 기록한다("해당없음" 도 답이다) —
        //  기록하지 않으면 앱을 켤 때마다 다시 묻는다.
        OnboardingProfileStore.shared.finish(Array(selection))
        UIAccessibility.post(notification: .announcement, argument: "무장애 정보를 저장했어요")
        onFinish(outcome)
    }
}

/// 온보딩 세 장이 공유하는 틀 — 오른쪽 위 로고, 왼쪽 위 단계 이름, 좌우 여백 36.
private struct OnboardingPage<Content: View>: View {
    var stepLabel: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                if let stepLabel {
                    Text(stepLabel)
                        .font(.notoSans(14, relativeTo: .subheadline))
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: 0)
                AuthBrandMark()
            }
            .padding(.top, 12)

            content()
        }
        .padding(.horizontal, AuthMetrics.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview("온보딩") {
    OnboardingView { _ in }
}
