import SwiftUI
import UIKit

/// 양쪽 정렬(justified) 텍스트 — SwiftUI Text가 미지원이라 UILabel로 래핑한다.
/// 한국어는 **글자 단위 줄바꿈**(byCharWrapping)으로 줄을 꽉 채워, 양쪽 정렬해도
/// 어간이 과하게 벌어지지 않게 한다 (단어 단위 줄바꿈은 줄 끝이 짧아 공백이 크게 늘어남).
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
        paragraph.lineBreakMode = .byCharWrapping   // 줄을 꽉 채워 어간이 벌어지지 않게

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
