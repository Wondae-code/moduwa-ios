import SwiftUI

/// 작성자 아바타 — 사진이 있으면 사진, 없으면 이니셜 원.
///
/// 다섯 자리(게시글 카드·상세, 후기 카드·상세, 장소 후기 줄)가 **각자 이니셜 원을 그리고
/// 있었다.** 프로필 사진(서버 042)이 들어오면서 같은 분기를 다섯 번 쓰게 되므로 한 곳으로 모은다.
///
/// 지름·글자 크기는 자리마다 달라서(32~40) 받는다. 사진은 정사각형으로 채워 자르고,
/// 못 받으면 이니셜로 되돌아간다 — 빈 회색 원이 남지 않게.
struct AuthorAvatar: View {
    let name: String
    var avatarURL: URL?
    var diameter: CGFloat = 40
    var fontSize: CGFloat = 15
    /// 이니셜 원의 배경. 자리에 따라 딥그린·라임을 쓴다.
    var background: Color = .deepGreen
    /// 이니셜 글자색. 라임처럼 밝은 배경에서는 흰 글자가 읽히지 않아 딥그린을 넘긴다.
    var foreground: Color = .white
    /// 사진이 없을 때 무엇을 그릴지.
    var fallback: Fallback = .initial

    /// 사진이 없을 때의 대체 그림.
    enum Fallback {
        /// **닉네임 첫 글자.** 목록(게시글·후기)에서 쓴다 — 누가 쓴 글인지 눈으로 가르는 데
        /// 글자 하나가 사람 그림보다 낫다. 같은 그림이 줄줄이 서면 다 같은 사람처럼 보인다.
        case initial
        /// **사람 상반신.** 내 프로필처럼 **누구인지 이미 아는 자리**에서 쓴다(2026-09-07 요청)
        /// — 거기서 내 이름 첫 글자는 알려 주는 것이 없다. 이름을 모르는 비로그인에서도 같다.
        case person
    }

    private var initial: String { String(name.prefix(1)) }

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
            switch fallback {
            case .initial:
                Text(initial)
                    .font(.notoSans(fontSize, .bold))
                    .foregroundStyle(foreground)
                    // 원은 고정 크기인데 글자만 커지면 접근성 글자 크기에서 원을 넘쳐 흐른다.
                    //  이름 첫 글자는 옆 텍스트에 이미 있는 정보라 장식으로 두고 크기를 묶는다
                    //  (`ReviewDetailView` 가 쓰던 규칙을 그대로 옮겼다).
                    .dynamicTypeSize(...DynamicTypeSize.large)
            case .person:
                Image(systemName: "person.fill")
                    .font(.system(size: diameter * 0.46))
                    .foregroundStyle(foreground)
            }
        }
    }
}

#Preview("아바타") {
    HStack(spacing: 12) {
        AuthorAvatar(name: "효도여행중")
        AuthorAvatar(name: "김민수", diameter: 32, fontSize: 13)
        AuthorAvatar(name: "이서연", avatarURL: URL(string: "https://example.com/none.jpg"))
        // 내 프로필 자리 — 이름 대신 사람 상반신.
        AuthorAvatar(
            name: "원대", diameter: 100, fontSize: 36,
            background: Color.moduwaGreen.opacity(0.3), foreground: .deepGreen,
            fallback: .person)
    }
    .padding()
}
