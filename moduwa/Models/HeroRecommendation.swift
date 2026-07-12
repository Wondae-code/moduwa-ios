import Foundation

/// 홈 상단 맞춤 접근성 추천 카드의 콘텐츠
struct HeroRecommendation: Sendable {
    let userName: String
    /// "휠체어로 이용하기 좋은\n여행지를 추천드려요" 같은 개인화 문구
    let headline: String
    let caption: String
    let tags: [String]
}
