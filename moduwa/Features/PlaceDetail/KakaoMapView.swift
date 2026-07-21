import KakaoMapsSDK
import SwiftUI

/// 카카오맵 임베드 뷰 — `Secrets.kakaoNativeAppKey` 설정 + 앱 시작 시 SDK 초기화가 선행돼야 한다.
/// 보기 전용(제스처 없음) 소형 지도 용도. 핀은 상위 뷰에서 오버레이로 얹는다.
/// `draw`는 뷰가 화면에 나타난 뒤 true로 — 레이아웃 전에 엔진을 켜면 렌더링이 멈춘다(카카오 공식 패턴).
struct KakaoMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    @Binding var draw: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(latitude: latitude, longitude: longitude)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer(
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 126)
        )
        context.coordinator.createController(container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        if draw {
            context.coordinator.activateEngineIfNeeded()
        } else {
            context.coordinator.pauseEngine()
        }
        // 레이아웃 확정 후 지도 서피스를 실제 크기에 맞춘다 — 초기 프레임과 어긋나면 비율이 깨져 보인다
        context.coordinator.syncViewRect(uiView.bounds.size)
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.pauseEngine()
        coordinator.controller?.resetEngine()
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private let position: MapPoint
        private var isActive = false
        var controller: KMController?

        init(latitude: Double, longitude: Double) {
            position = MapPoint(longitude: longitude, latitude: latitude)
        }

        func createController(_ container: KMViewContainer) {
            let controller = KMController(viewContainer: container)
            controller.delegate = self
            self.controller = controller
            controller.prepareEngine()
        }

        func activateEngineIfNeeded() {
            guard !isActive else { return }
            isActive = true
            controller?.activateEngine()
        }

        func pauseEngine() {
            guard isActive else { return }
            isActive = false
            controller?.pauseEngine()
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
            syncViewRect(size)
        }

        /// 지도 뷰 서피스를 컨테이너 크기에 동기화 (0 크기 방어)
        func syncViewRect(_ size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }
            (controller?.getView("placeDetailMap") as? KakaoMap)?.viewRect = CGRect(origin: .zero, size: size)
        }
    }
}
