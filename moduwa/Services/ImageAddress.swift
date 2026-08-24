import Foundation

extension URL {
    /// 관광공사 이미지 주소를 URL 로. **평문 `http://` 는 `https://` 로 올린다.**
    ///
    /// 원본에 두 가지가 섞여 온다(2026-08-23 기준 저장된 플랜 항목 54개 중 19개가 http).
    /// iOS 는 ATS 로 평문 http 이미지 로드를 막으므로 그대로 쓰면 **사진이 조용히 안 뜬다** —
    /// 오류도 없이 회색 자리만 남아서, 사진이 없는 장소인지 못 불러온 것인지 구분되지 않는다.
    /// 같은 호스트(`tong.visitkorea.or.kr`)가 https 로도 그대로 서비스한다.
    ///
    /// 저장된 데이터를 고치지 않고 **읽을 때** 올리는 이유: 이미 서버에 http 로 들어간 값이
    /// 있고(추천 코스가 그대로 저장했다), 앞으로 원본이 또 http 를 줄 수도 있다.
    init?(imageAddress text: String?) {
        guard let text, !text.isEmpty else { return nil }
        let upgraded = text.hasPrefix("http://")
            ? "https://" + text.dropFirst("http://".count)
            : text
        self.init(string: upgraded)
    }
}
