import KakaoMapsSDK
import SwiftUI

/// 카카오맵 임베드 뷰 — `Secrets.kakaoNativeAppKey` 설정 + 앱 시작 시 SDK 초기화가 선행돼야 한다.
/// 보기 전용(제스처 없음) 소형 지도 용도. 중심 좌표에 SDK POI 핀을 찍는다.
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
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 175)
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
        // 레이아웃 확정 후 지도 서피스를 실제 크기에 맞춘다 — 어긋나면 비율 왜곡·하단 잘림이 생긴다
        context.coordinator.syncViewRect(uiView.bounds.size)
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.pauseEngine()
        coordinator.controller?.resetEngine()
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private static let viewName = "placeDetailMap"
        private let position: MapPoint
        private var isActive = false
        private weak var container: KMViewContainer?
        var controller: KMController?

        init(latitude: Double, longitude: Double) {
            position = MapPoint(longitude: longitude, latitude: latitude)
        }

        func createController(_ container: KMViewContainer) {
            self.container = container
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
                viewName: Self.viewName,
                defaultPosition: position,
                defaultLevel: 16
            )
            controller?.addView(mapviewInfo)
        }

        // 지도 뷰 생성 완료 — 실제 컨테이너 크기로 서피스를 맞추고 POI 핀을 찍는다
        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            if let size = container?.bounds.size { syncViewRect(size) }
            addPin()
        }

        /// 중심 좌표 핀 — 카카오 SDK POI (엔진이 직접 렌더링)
        private func addPin() {
            guard let mapView = controller?.getView(Self.viewName) as? KakaoMap else { return }
            let manager = mapView.getLabelManager()

            let layerOptions = LabelLayerOptions(
                layerID: "placePinLayer",
                competitionType: .none,
                competitionUnit: .symbolFirst,
                orderType: .rank,
                zOrder: 10_000
            )
            let layer = manager.addLabelLayer(option: layerOptions)

            // 카카오맵 공식 핀 아이콘 (디자인 시안의 kakao_map 에셋)
            let iconStyle = PoiIconStyle(
                symbol: UIImage(named: "kakao_map"),
                anchorPoint: CGPoint(x: 0.5, y: 1.0)
            )
            let poiStyle = PoiStyle(
                styleID: "placePinStyle",
                styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)]
            )
            manager.addPoiStyle(poiStyle)

            let poi = layer?.addPoi(option: PoiOptions(styleID: "placePinStyle"), at: position)
            poi?.show()
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
            (controller?.getView(Self.viewName) as? KakaoMap)?.viewRect = CGRect(origin: .zero, size: size)
        }
    }
}
