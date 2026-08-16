import KakaoMapsSDK
import SwiftUI

/// 지도를 움직여 한 점을 고르는 지도 — "나만의 장소" 위치 선택(트리플 스샷 2단계, 시안 519:1178).
///
/// 핀을 지도 위에 POI 로 찍지 않는다. **핀은 화면 한가운데 고정**이고 지도가 그 밑에서 움직인다
/// (호출부가 SwiftUI 오버레이로 그린다) — POI 로 두면 카메라가 멈출 때마다 지우고 다시 찍어야 하고,
/// 그 사이 한 프레임씩 핀이 사라진다.
///
/// 그래서 이 뷰가 하는 일은 **멈춘 자리의 좌표를 알려 주는 것** 하나다.
struct PlanLocationPickerMap: UIViewRepresentable {
    /// 처음 보여 줄 자리. 플랜의 여행 지역을 그대로 쓴다(`TravelRegion.mapCamera`) —
    /// 경주 여행을 짜는 사람에게 서울을 띄워 놓고 찾아오게 할 이유가 없다.
    let initialCamera: RegionMapCamera
    /// 카메라가 멈출 때마다 화면 한가운데의 좌표를 넘긴다.
    var onCenterChanged: (Double, Double) -> Void
    @Binding var draw: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(initialCamera: initialCamera, onCenterChanged: onCenterChanged)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = ResizingMapContainer(
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 400)
        )
        container.onLayout = { [weak coordinator = context.coordinator] size in
            coordinator?.syncViewRect(size)
        }
        context.coordinator.createController(container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        if draw {
            context.coordinator.activateEngineIfNeeded()
        } else {
            context.coordinator.pauseEngine()
        }
        context.coordinator.syncViewRect(uiView.bounds.size)
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.pauseEngine()
        coordinator.controller?.resetEngine()
    }

    final class Coordinator: NSObject, MapControllerDelegate {
        private static let viewName = "planLocationPicker"

        private let initialCamera: RegionMapCamera
        private let onCenterChanged: (Double, Double) -> Void
        private var isActive = false
        /// SDK 의 이벤트 핸들러는 **반환값을 붙들고 있어야 살아 있다.** 버리면 콜백이 오지 않는다.
        private var cameraHandler: DisposableEventHandler?
        private weak var container: KMViewContainer?
        var controller: KMController?

        init(initialCamera: RegionMapCamera, onCenterChanged: @escaping (Double, Double) -> Void) {
            self.initialCamera = initialCamera
            self.onCenterChanged = onCenterChanged
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

        func addViews() {
            controller?.addView(MapviewInfo(
                viewName: Self.viewName,
                defaultPosition: MapPoint(longitude: initialCamera.longitude,
                                          latitude: initialCamera.latitude),
                defaultLevel: initialCamera.zoomLevel
            ))
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            if let size = container?.bounds.size { syncViewRect(size) }
            guard let mapView = controller?.getView(Self.viewName) as? KakaoMap else { return }

            cameraHandler = mapView.addCameraStoppedEventHandler(target: self) { coordinator in
                { _ in coordinator.reportCenter() }
            }
            // 손대지 않고 바로 "확인"을 누를 수도 있다 — 처음 자리도 한 번 알려 준다.
            reportCenter()
        }

        /// 화면 한가운데가 가리키는 좌표. 핀이 거기 고정돼 있으므로 이 값이 곧 고른 지점이다.
        private func reportCenter() {
            guard let mapView = controller?.getView(Self.viewName) as? KakaoMap else { return }
            let rect = mapView.viewRect
            guard rect.width > 0, rect.height > 0 else { return }
            let wgs = mapView.getPosition(CGPoint(x: rect.midX, y: rect.midY)).wgsCoord
            onCenterChanged(wgs.latitude, wgs.longitude)
        }

        func authenticationFailed(_ errorCode: Int, desc: String) {
            print("[KakaoMap] 인증 실패(\(errorCode)): \(desc)")
        }

        func containerDidResized(_ size: CGSize) {
            syncViewRect(size)
        }

        func syncViewRect(_ size: CGSize) {
            guard size.width > 0, size.height > 0,
                  let mapView = controller?.getView(Self.viewName) as? KakaoMap else { return }
            mapView.viewRect = CGRect(origin: .zero, size: size)
            // 카카오 로고는 가려도 지워도 안 되는 필수 표기다(이용약관). 좌하단에 둔다.
            mapView.setLogoPosition(
                origin: GuiAlignment(vAlign: .bottom, hAlign: .left),
                position: CGPoint(x: 12, y: 12)
            )
        }
    }
}
