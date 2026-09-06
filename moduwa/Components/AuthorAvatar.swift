import SwiftUI

/// 작성자 아바타 — 사진이 있으면 사진, 없으면 **사람 상반신**.
///
/// 다섯 자리(게시글 카드·상세, 후기 카드·상세, 장소 후기 줄)가 **각자 이니셜 원을 그리고
/// 있었다.** 프로필 사진(서버 042)이 들어오면서 같은 분기를 다섯 번 쓰게 되므로 한 곳으로 모은다.
///
/// **닉네임 첫 글자를 그리다가 그만뒀다**(2026-09-07 요청). 아바타 옆에는 늘 이름이 적혀
/// 있어서 첫 글자가 더 알려 주는 것이 없고, 자리마다 다른 그림이 나오면 같은 앱으로 안 보인다.
/// 대신 한 가지 기본 그림을 쓴다 — 카카오톡·인스타그램이 하는 방식이고, 누가 쓴 글인지는
/// 옆의 이름이 말한다.
///
/// 지름은 자리마다 달라서(32~100) 받는다. 사진은 정사각형으로 채워 자르고, 못 받으면
/// 기본 그림으로 되돌아간다 — 빈 회색 원이 남지 않게.
struct AuthorAvatar: View {
    let name: String
    var avatarURL: URL?
    var diameter: CGFloat = 40
    /// 이니셜 원의 배경. 자리에 따라 딥그린·라임을 쓴다.
    /// 원 색. 기본은 **연한 라임** — 앱의 모든 아바타가 같은 색이다(2026-09-07 요청).
    /// 예전에는 목록만 딥그린 원 + 흰 실루엣, 프로필만 라임 원 + 딥그린 실루엣이었다.
    /// 딥그린 실루엣이 이 배경에서 **7:1** 로 또렷하다(WCAG 비텍스트 3:1 을 넘는다).
    var background: Color = Color.moduwaGreen.opacity(0.3)
    /// 이니셜 글자색. 라임처럼 밝은 배경에서는 흰 글자가 읽히지 않아 딥그린을 넘긴다.
    var foreground: Color = .deepGreen

    var body: some View {
        Group {
            if let avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        // 주소가 있는데 못 받았다 — 빈 원보다 이니셜이 낫다.
                        placeholder
                    default:
                        Color.photoPlaceholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        // 이름은 옆줄에 이미 적혀 있다 — 아바타까지 읽으면 같은 이름을 두 번 듣는다.
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        background.overlay {
            // 카카오톡 기본 프로필처럼 **원을 꽉 채우고 어깨가 아래로 잘려 나간다**
            //  (2026-09-07 요청). 작게 두면 원 안에 떠 있는 픽토그램으로 보이고, 키워서
            //  가장자리에 닿게 하면 그것 자체가 프로필 그림이 된다.
            //  아래로 내리는 이유: 그러지 않으면 머리 위에 빈자리가 남고 어깨가 안 잘린다.
            Image(systemName: "person.fill")
                .font(.system(size: diameter * 1.0))
                .foregroundStyle(foreground)
                .offset(y: diameter * 0.20)
        }
    }
}

#Preview("아바타") {
    HStack(spacing: 12) {
        AuthorAvatar(name: "효도여행중")
        AuthorAvatar(name: "김민수", diameter: 32)
        AuthorAvatar(name: "이서연", avatarURL: URL(string: "https://example.com/none.jpg"))
        AuthorAvatar(name: "원대", diameter: 100)
    }
    .padding()
}
