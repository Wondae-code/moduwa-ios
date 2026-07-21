import SwiftUI
import UIKit

/// SwiftUI `Text`는 양쪽 정렬(justified)을 지원하지 않아(`multilineTextAlignment`는 leading/center/trailing만),
/// 장소 설명 본문처럼 양쪽 정렬이 필요한 곳에 UILabel을 감싸 사용한다.
/// - 한글 줄바꿈은 `hangulWordPriority`로 자연스럽게 처리한다.
/// - `lineLimit`로 접힘/펼침 상태를 표현한다. UILabel에서 양쪽 정렬과 말줄임(`byTruncatingTail`)은
///   문단 스타일이 서로를 덮어써 공존하지 못하므로, 접힘 상태에선 word wrapping을 유지한 채
///   지정한 줄 수에서 잘라낸다(Figma 접힘 목업도 말줄임 없이 줄 경계에서 끊긴다).
struct JustifiedText: UIViewRepresentable {
    let text: String
    var font: UIFont
    var textColor: UIColor
    var lineSpacing: CGFloat = 0
    /// nil이면 전체 표시, 값이 있으면 해당 줄 수까지만 표시한다.
    var lineLimit: Int?

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.numberOfLines = lineLimit ?? 0

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping      // 양쪽 정렬은 word wrapping에서만 동작
        paragraph.lineBreakStrategy = .hangulWordPriority

        // 앱의 나머지 텍스트와 동일하게 Dynamic Type(.body) 스케일을 따른다.
        let scaledFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: font)

        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: scaledFont,
                .foregroundColor: textColor,
                .paragraphStyle: paragraph,
            ]
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        label.preferredMaxLayoutWidth = width
        let fitting = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitting.height))
    }
}
