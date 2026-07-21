import KakaoMapsSDK
import SwiftUI

/// 카카오맵 임베드 뷰 — `Secrets.kakaoNativeAppKey` 설정 + 앱 시작 시 SDK 초기화가 선행돼야 한다.
/// 보기 전용(제스처 없음) 소형 지도 용도. 핀은 상위 뷰에서 오버레이로 얹는다.
struct KakaoMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(latitude: latitude, longitude: longitude)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer()
        context.coordinator.createController(container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {}

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.controller?.pauseEngine()
        coordinator.controller?.resetEngine()
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private let position: MapPoint
        var controller: KMController?

        init(latitude: Double, longitude: Double) {
            position = MapPoint(longitude: longitude, latitude: latitude)
        }

        func createController(_ container: KMViewContainer) {
            let controller = KMController(viewContainer: container)
            controller.delegate = self
            self.controller = controller
            controller.prepareEngine()
            controller.activateEngine()
        }

        // 엔진 준비 완료 — 지도 뷰 추가
        func addViews() {
            let mapviewInfo = MapviewInfo(
                viewName: "placeDetailMap",
                defaultPosition: position,
                defaultLevel: 16
            )
            controller?.addView(mapviewInfo)
        }

        func authenticationFailed(_ errorCode: Int, desc: String) {
            // 키 미등록/네트워크 오류 — 지도가 비어 보인다. 콘솔로만 알린다.
            print("[KakaoMap] 인증 실패(\(errorCode)): \(desc)")
        }

        func containerDidResized(_ size: CGSize) {
            (controller?.getView("placeDetailMap") as? KakaoMap)?.viewRect = CGRect(origin: .zero, size: size)
        }
    }
}
