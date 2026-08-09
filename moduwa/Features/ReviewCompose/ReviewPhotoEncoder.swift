import UIKit

/// 후기 사진을 업로드 전에 앱에서 줄여 JPEG로 다시 인코딩한다.
///
/// **서버는 리사이즈하지 않는다.** 원본을 그대로 저장하므로 줄이는 책임이 앱에 있다.
///
/// 실측으로 확인한 함정 — 무조건 `maxDimension`에 맞추면 안 된다:
/// 940×627 사진(133KB)을 1280px "규격"으로 맞추면 **확대**되면서 394KB로 오히려 커졌다.
/// 그래서 축소 배율은 1.0을 넘지 않게 잠근다(`min(1, …)`). 장변이 상한 이하인 사진은 크기를 건드리지 않는다.
///
/// 재인코딩의 부수 효과로 GPS 등 EXIF가 사라진다. 후기 사진에 촬영 위치가 따라붙지 않는 건
/// 의도한 이점이라 원본 바이트를 통과시키지 않고 항상 다시 인코딩한다.
enum ReviewPhotoEncoder {
    /// 장변 상한. 이보다 작은 사진은 확대하지 않는다.
    static let maxDimension: CGFloat = 1280
    /// 서버의 장당 상한 (2MB)
    static let maxBytes = 2 * 1024 * 1024
    /// 기본 JPEG 품질 — 1280px 규격에서 약 400KB
    static let quality: CGFloat = 0.8

    /// PhotosPicker가 준 원본 바이트(HEIC 포함) → 업로드용 JPEG 바이트.
    /// 디코딩할 수 없는 데이터면 nil.
    static func encode(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return encode(image)
    }

    static func encode(_ image: UIImage) -> Data? {
        guard var encoded = jpeg(image, maxDimension: maxDimension, quality: quality) else { return nil }

        // 2MB를 넘는 사진(초고해상도·노이즈가 많은 사진)은 서버가 거부한다.
        // 품질을 먼저 낮추고, 그래도 넘으면 장변을 줄인다 — 화질보다 "올라가는 것"이 먼저다.
        var dimension = maxDimension
        var currentQuality = quality
        while encoded.count > maxBytes {
            if currentQuality > 0.5 {
                currentQuality -= 0.15
            } else if dimension > 640 {
                dimension = max(640, dimension * 0.75)
            } else {
                break   // 더 줄일 수 없다 — 서버 오류로 사용자에게 알린다
            }
            guard let retry = jpeg(image, maxDimension: dimension, quality: currentQuality) else { break }
            encoded = retry
        }
        return encoded
    }

    private static func jpeg(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }

        // ⚠️ 여기가 핵심 — 1.0을 넘지 않게 잠근다. 작은 사진을 늘리면 용량만 커진다.
        let scale = min(1, maxDimension / longest)

        // 배율이 1이어도 그린다. 렌더링을 건너뛰고 원본 바이트를 쓰면 EXIF가 남고,
        // HEIC 원본은 JPEG로 바뀌지도 않는다.
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        // 1 고정 — 화면 배율(2x/3x)을 따르면 target보다 2~3배 큰 비트맵이 나온다
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
