import SwiftUI

/// 홈 "여행자 리뷰" 섹션의 게시글 카드.
///
/// `ReviewCard` 의 시각 언어를 따르되(사진 콜라주 → 작성자 → 본문, 흰 카드·라운드·연한 그림자)
/// **게시글에 없는 것은 빼고 있는 것을 넣는다**:
///  - 별점·재방문 없음 — 게시글은 장소를 평가하는 글이 아니다
///  - 대신 **붙인 장소**와 **작성자가 고른 무장애 정보**를 보여 준다(게시글에만 있는 값이다)
struct PostCard: View {
    let post: TravelPost

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 사진이 없는 게시글이 정상이다(글만 쓰는 것이 기본이다) — 그때는 사진 칸을 두지 않는다.
            // 회색 자리 표시를 깔면 사진이 빠진 것처럼 읽힌다(`ReviewCard` 와 같은 판단).
            if !post.imageURLs.isEmpty {
                photoArea
                    .frame(height: 180)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                authorRow

                Text(post.body)
                    .font(.notoSans(16))
                    .foregroundStyle(.textSecondary)
                    .lineSpacing(6)
                    // 홈 카드는 미리보기다 — 긴 글은 잘라 두고 상세에서 다 읽게 한다.
                    .lineLimit(6)

                if !post.places.isEmpty { placeRow }
                if !post.accessFeatures.isEmpty { accessRow }
                likeCommentRow
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        // 폭은 내용이 아니라 카드가 정한다 — 사진 없는 글에서 카드가 글자 길이만큼 좁아지지 않게.
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .shadow(color: .deepGreen.opacity(0.05), radius: 10, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    /// 사진 1장이면 꽉, 2장이면 좌우 분할, 3장 이상이면 좌 1 + 우 2 에 "+N".
    /// `ReviewCard` 보다 단순하게 두는 이유: 게시글 사진은 최대 5장이고 홈은 미리보기다.
    private var photoArea: some View {
        HStack(spacing: 1) {
            photoSlot(0)
            if post.imageURLs.count == 2 {
                photoSlot(1)
            } else if post.imageURLs.count > 2 {
                VStack(spacing: 1) {
                    photoSlot(1)
                    photoSlot(2, overflow: post.imageURLs.count - 3)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func photoSlot(_ index: Int, overflow: Int = 0) -> some View {
        Color.photoPlaceholder
            .overlay {
                if index < post.imageURLs.count {
                    AsyncImage(url: post.imageURLs[index]) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.photoPlaceholder
                    }
                }
            }
            .overlay {
                if overflow > 0 {
                    ZStack {
                        Color.black.opacity(0.4)
                        Text("+\(overflow)")
                            .font(.notoSans(18, .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .clipped()
    }

    private var authorRow: some View {
        HStack(spacing: 9) {
            // 프로필 사진이 없다 — 작성 화면과 같이 닉네임 첫 글자를 원에 담는다.
            Text(String(post.author.prefix(1)))
                .font(.notoSans(14, .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.deepGreen, in: Circle())
                .accessibilityHidden(true)

            Text(post.author)
                .font(.notoSans(14, .bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(RelativeTimeText.string(from: post.createdAt))
                .font(.caption12)
                .foregroundStyle(.textSecondary)
        }
    }

    /// 붙인 장소. 여러 곳이면 첫 곳과 나머지 개수만 보여 준다 — 카드가 목록을 나열할 자리가 아니다.
    private var placeRow: some View {
        HStack(spacing: 4) {
            Image("location_on")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(.deepGreen)

            Text(placeSummary)
                .font(.meta13)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }

    /// 작성자가 고른 무장애 정보. 카드에서는 아이콘만 — 이름까지 쓰면 줄이 넘친다.
    private var accessRow: some View {
        HStack(spacing: 6) {
            ForEach(post.accessFeatures, id: \.self) { feature in
                Image(feature.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: feature.iconSize(height: 13).width, height: 13)
                    .foregroundStyle(.deepGreen)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "무장애 정보 " + post.accessFeatures.map(\.label).joined(separator: ", "))
    }

    /// 좋아요·댓글 수. 하트는 **표시만** 한다 — 카드에서 누르면 목록 전체가 다시 그려지고,
    /// 어느 글에 눌렀는지 눈으로 따라가기 어렵다. 누르는 것은 상세에서 한다.
    private var likeCommentRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: post.likedByMe ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(post.likedByMe ? .moduwaGreen : .textSecondary)
                Text("\(post.likeCount)")
            }
            HStack(spacing: 4) {
                Image("chat_bubble")
                    .renderingMode(.template)
                    .foregroundStyle(.moduwaGreen)
                Text("\(post.commentCount)")
            }
        }
        .font(.meta13)
        .foregroundStyle(.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("좋아요 \(post.likeCount)개, 댓글 \(post.commentCount)개")
    }

    private var placeSummary: String {
        guard let first = post.places.first else { return "" }
        return post.places.count > 1
            ? "\(first.name) 외 \(post.places.count - 1)곳"
            : first.name
    }

    private var accessibilitySummary: String {
        var parts = [post.author, post.body]
        if !post.places.isEmpty { parts.append(placeSummary) }
        if !post.imageURLs.isEmpty { parts.append("사진 \(post.imageURLs.count)장") }
        return parts.joined(separator: ", ")
    }
}
