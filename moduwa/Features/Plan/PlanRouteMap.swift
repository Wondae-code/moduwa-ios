import KakaoMapsSDK
import SwiftUI

/// SwiftUI 프레임이 바뀌어도 엔진 뷰포트를 따라가게 하려고 레이아웃 시점을 넘겨받는다.
/// (`updateUIView` 는 입력이 바뀔 때만 불려서 크기 변경을 놓친다)
final class ResizingMapContainer: KMViewContainer {
    var onLayout: ((CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds.size)
    }
}

/// 나만의 장소는 라임, 그 외는 딥그린 — `PlanPlace.isCustom` 하나로 갈린다.
/// 지도 핀과 목록 뱃지가 같은 모양이라 한 뷰를 공유하고, 지도 쪽은 이 뷰를 이미지로 구워 POI 심볼로 쓴다.
/// 시안(509:527)에서 지도 핀과 목록 뱃지는 24×24로 완전히 같은 규격이다.
struct PlanNumberBadge: View {
    let number: Int
    let isCustom: Bool

    var body: some View {
        Text("\(number)")
            .font(.notoSans(16, .bold, relativeTo: .headline))
            .tracking(-0.064)
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(isCustom ? Color.moduwaGreen : Color.deepGreen, in: Circle())
            .overlay { Circle().stroke(.white, lineWidth: 1) }
    }
}

/// 플랜 상세의 경로 지도 — 카카오맵 위에 번호 핀과 점선 경로를 그린다.
///
/// `Secrets.kakaoNativeAppKey` 설정 + 앱 시작 시 SDK 초기화가 선행돼야 한다.
/// `draw`는 뷰가 화면에 나타난 뒤 true로 — 레이아웃 전에 엔진을 켜면 렌더링이 멈춘다(카카오 공식 패턴).
struct PlanRouteMap: UIViewRepresentable {
    /// 좌표가 있는 정류지만 순서대로.
    let stops: [PlanStop]
    /// 바텀시트에 가리는 높이. 이만큼 하단 마진을 주면 카메라가 드러난 영역에만 경로를 맞춘다.
    let bottomInset: CGFloat
    /// 좌표가 있는 정류지가 하나도 없을 때 카메라를 맞출 자리 — 플랜의 여행 지역이다.
    /// 핀도 경로도 없이 그 지역만 보여 준다.
    var regionCamera: RegionMapCamera?
    @Binding var draw: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(stops: stops, bottomInset: bottomInset, regionCamera: regionCamera)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        // 초기 크기는 임시값이다 — 실제 크기는 아래 layoutSubviews 콜백이 잡아 준다.
        let container = ResizingMapContainer(
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 331)
        )
        // SwiftUI 는 프레임 크기만 바뀔 때 updateUIView 를 부르지 않는다. 그대로 두면 엔진의
        // viewRect 가 옛 크기에 머물러, 카카오 로고가 **옛 뷰포트의 모서리**(지금 화면에서는
        // 오른쪽 가운데)에 찍히고 카메라 맞춤도 어긋난다. UIKit 레이아웃에 직접 붙여 동기화한다.
        container.onLayout = { [weak coordinator = context.coordinator] size in
            coordinator?.syncViewRect(size)
        }
        context.coordinator.createController(container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        context.coordinator.updateStops(stops)
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
        private static let viewName = "planRouteMap"
        private static let poiLayerID = "planRoutePoiLayer"
        private static let routeLayerID = "planRouteLayer"
        private static let routeStyleID = "planRouteStyle"

        /// 점선 계산은 위경도로 하는 게 편해서 `MapPoint`와 별도로 들고 있는다.
        struct Coordinate {
            let latitude: Double
            let longitude: Double
        }

        /// 다시 그릴지 판단하는 기준. 순서만 바뀌어도 번호 뱃지가 전부 달라진다.
        private var stops: [PlanStop]
        private var points: [MapPoint]
        private var coordinates: [Coordinate]
        private var badges: [(point: MapPoint, image: UIImage?)]
        private let bottomInset: CGFloat
        /// 정류지가 없을 때만 쓰인다. 플랜이 열려 있는 동안 지역은 바뀌지 않으므로 초기화 때 한 번 받는다.
        private let regionCamera: RegionMapCamera?
        private var isActive = false
        private var didDrawOverlays = false
        private weak var container: KMViewContainer?
        var controller: KMController?

        @MainActor
        init(stops: [PlanStop], bottomInset: CGFloat, regionCamera: RegionMapCamera?) {
            self.stops = stops
            self.bottomInset = bottomInset
            self.regionCamera = regionCamera
            (coordinates, points, badges) = Self.derive(from: stops)
        }

        /// 좌표가 있는 정류지만 순서대로 뽑아 지도에 쓸 값으로 바꾼다.
        @MainActor
        private static func derive(
            from stops: [PlanStop]
        ) -> ([Coordinate], [MapPoint], [(point: MapPoint, image: UIImage?)]) {
            let located = stops.compactMap { stop -> (Coordinate, Bool)? in
                guard let latitude = stop.place.latitude, let longitude = stop.place.longitude else { return nil }
                return (Coordinate(latitude: latitude, longitude: longitude), stop.place.isCustom)
            }
            let coordinates = located.map(\.0)
            let points = located.map { MapPoint(longitude: $0.0.longitude, latitude: $0.0.latitude) }
            let badges = zip(points, located.enumerated()).map { point, item in
                (point: point, image: Self.badgeImage(number: item.offset + 1, isCustom: item.element.1))
            }
            return (coordinates, points, badges)
        }

        /// 정류지가 바뀌면 핀·경로를 지우고 다시 그린다.
        ///
        /// 편집에서 순서를 바꾸면 좌표 집합은 그대로여도 **번호 뱃지가 전부 달라진다** —
        /// 좌표만 비교하면 이 경우를 놓치므로 `PlanStop` 배열 자체를 비교한다.
        @MainActor
        func updateStops(_ newStops: [PlanStop]) {
            guard newStops != stops else { return }
            stops = newStops
            (coordinates, points, badges) = Self.derive(from: newStops)

            guard let mapView = controller?.getView(Self.viewName) as? KakaoMap else { return }
            mapView.getLabelManager().removeLabelLayer(layerID: Self.poiLayerID)
            mapView.getShapeManager().removeShapeLayer(layerID: Self.routeLayerID)
            didDrawOverlays = false
            drawOverlaysIfNeeded()
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
            // 정류지 → 지역 → 경주 순으로 물러선다. 마지막 폴백은 엔진이 켜질 때 잠깐 쓰일 뿐,
            // 곧 `fitCamera`가 제자리를 잡는다.
            let fallback = regionCamera.map {
                MapPoint(longitude: $0.longitude, latitude: $0.latitude)
            }
            let mapviewInfo = MapviewInfo(
                viewName: Self.viewName,
                defaultPosition: points.first ?? fallback
                    ?? MapPoint(longitude: 129.2265, latitude: 35.8348),
                defaultLevel: points.isEmpty ? (regionCamera?.zoomLevel ?? 11) : 11
            )
            controller?.addView(mapviewInfo)
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            if let size = container?.bounds.size { syncViewRect(size) }
            drawOverlaysIfNeeded()
        }

        private func drawOverlaysIfNeeded() {
            guard !didDrawOverlays,
                  let mapView = controller?.getView(Self.viewName) as? KakaoMap else { return }
            didDrawOverlays = true

            // 시트에 가리는 만큼 하단 마진 — 카메라 맞춤이 드러난 영역만 쓰도록 한다.
            //  로고는 화면 맨 아래에 고정돼 있고 핀은 이 마진 덕에 그보다 위에 맞춰지므로
            //  로고 몫을 따로 뺄 필요가 없다.
            mapView.setMargins(UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0))

            addPins(on: mapView)
            // 점선 길이를 화면 기준으로 잡으려면 확정된 카메라가 필요하다 — 맞춘 뒤에 그린다.
            fitCamera(on: mapView) { [weak self] in
                self?.addDashedRoute(on: mapView)
            }
        }

        // MARK: 경로

        /// 시안(509:564)은 stroke-width 2에 dasharray "4 4"인 점선이다.
        ///
        /// 카카오 SDK엔 dash 옵션이 없다(`PerLevelPolylineStyle`에도 없음). 유일한 내장 수단인
        /// `RoutePattern`(패턴 이미지 스탬프)은 이 경로에서 마지막 정류지 근처에만 찍혔다 —
        /// 2026-08-02 확인: distance 8/10/1900 무관, 세그먼트 분할 무관, 같은 좌표의 실선은 전 구간 정상.
        /// 그래서 점선 조각 하나하나를 짧은 실선으로 만들어 한 shape에 담는다.
        ///
        /// 조각 길이는 미터 단위로 고정되므로 줌이 바뀌면 화면상 간격이 달라진다. 지금은 카메라가
        /// 고정이라 문제없지만, 제스처를 열면 `addCameraStoppedEventHandler`에서 다시 그려야 한다.
        private func addDashedRoute(on mapView: KakaoMap) {
            guard coordinates.count > 1 else { return }
            let metersPerPoint = Self.metersPerPoint(on: mapView)
            guard metersPerPoint > 0 else { return }

            let dashes = Self.dashSegments(
                along: coordinates,
                dashLength: 4 * metersPerPoint,
                gapLength: 4 * metersPerPoint
            )
            guard !dashes.isEmpty else { return }

            let manager = mapView.getShapeManager()
            // capType 기본값(.square)은 조각 양끝을 굵기의 절반만큼 늘려 4/4가 5/3으로 나온다.
            // SVG stroke-linecap 기본값과 같은 .butt이어야 시안 그대로다.
            let styleSet = PolylineStyleSet(
                styleSetID: Self.routeStyleID,
                styles: [PolylineStyle(styles: [
                    PerLevelPolylineStyle(bodyColor: UIColor(Color.textPrimary), bodyWidth: 2, level: 0)
                ])],
                capType: .butt
            )
            manager.addPolylineStyleSet(styleSet)

            let layer = manager.addShapeLayer(layerID: Self.routeLayerID, zOrder: 9_000)
            let options = MapPolylineShapeOptions(styleID: Self.routeStyleID, zOrder: 0)
            options.polylines = dashes.map { dash in
                MapPolyline(line: dash.map { MapPoint(longitude: $0.longitude, latitude: $0.latitude) }, styleIndex: 0)
            }
            layer?.addMapPolylineShape(options)?.show()
        }

        /// 화면 100pt가 실제 몇 미터인지. 점선 조각을 화면 기준 4pt로 잡으려면 필요하다.
        /// SDK에 월드→스크린 변환이 없어 반대 방향(`getPosition`)으로 역산한다.
        private static func metersPerPoint(on mapView: KakaoMap) -> Double {
            let rect = mapView.viewRect
            guard rect.width > 120 else { return 0 }
            let left = mapView.getPosition(CGPoint(x: rect.midX - 50, y: rect.midY)).wgsCoord
            let right = mapView.getPosition(CGPoint(x: rect.midX + 50, y: rect.midY)).wgsCoord
            return distance(
                from: Coordinate(latitude: left.latitude, longitude: left.longitude),
                to: Coordinate(latitude: right.latitude, longitude: right.longitude)
            ) / 100
        }

        /// 경로를 따라가며 `dashLength`만큼 긋고 `gapLength`만큼 띄운 구간들을 만든다.
        /// 한 조각이 여러 다리에 걸치면 다리 경계에서 잘려 여러 폴리라인이 되지만 이어져 보인다.
        private static func dashSegments(
            along path: [Coordinate],
            dashLength: Double,
            gapLength: Double
        ) -> [[Coordinate]] {
            guard dashLength > 0, gapLength > 0 else { return [] }
            var result: [[Coordinate]] = []
            var isDrawing = true
            var consumed = 0.0

            for (start, end) in zip(path, path.dropFirst()) {
                let legLength = distance(from: start, to: end)
                guard legLength > 0 else { continue }
                var travelled = 0.0

                while travelled < legLength {
                    // 좌표가 비정상이어서 조각이 폭증하는 경우를 막는다.
                    guard result.count < 2_000 else { return result }

                    let target = isDrawing ? dashLength : gapLength
                    let step = min(target - consumed, legLength - travelled)
                    if isDrawing {
                        result.append([
                            interpolate(start, end, travelled / legLength),
                            interpolate(start, end, (travelled + step) / legLength),
                        ])
                    }
                    travelled += step
                    consumed += step
                    if consumed >= target - 1e-6 {
                        consumed = 0
                        isDrawing.toggle()
                    }
                }
            }
            return result
        }

        /// 등거리 원통도법 근사 — 한 화면에 담기는 거리에선 오차가 무시할 수준이다.
        private static func distance(from a: Coordinate, to b: Coordinate) -> Double {
            let midLatitude = (a.latitude + b.latitude) / 2 * .pi / 180
            let dLatitude = (b.latitude - a.latitude) * 111_320
            let dLongitude = (b.longitude - a.longitude) * 111_320 * cos(midLatitude)
            return (dLatitude * dLatitude + dLongitude * dLongitude).squareRoot()
        }

        private static func interpolate(_ a: Coordinate, _ b: Coordinate, _ t: Double) -> Coordinate {
            Coordinate(
                latitude: a.latitude + (b.latitude - a.latitude) * t,
                longitude: a.longitude + (b.longitude - a.longitude) * t
            )
        }

        // MARK: 핀

        private func addPins(on mapView: KakaoMap) {
            let manager = mapView.getLabelManager()
            let layer = manager.addLabelLayer(option: LabelLayerOptions(
                layerID: Self.poiLayerID,
                competitionType: .none,
                competitionUnit: .symbolFirst,
                orderType: .rank,
                zOrder: 10_000
            ))

            for (index, badge) in badges.enumerated() {
                guard let image = badge.image else { continue }
                let styleID = "planPin\(index)"
                manager.addPoiStyle(PoiStyle(styleID: styleID, styles: [
                    PerLevelPoiStyle(
                        iconStyle: PoiIconStyle(symbol: image, anchorPoint: CGPoint(x: 0.5, y: 0.5)),
                        level: 0
                    )
                ]))
                let poi = layer?.addPoi(option: PoiOptions(styleID: styleID), at: badge.point)
                poi?.show()
            }
        }

        /// 목록 뱃지와 같은 SwiftUI 뷰를 그대로 이미지로 구워 쓴다 — 두 곳이 어긋날 일이 없다.
        @MainActor
        private static func badgeImage(number: Int, isCustom: Bool) -> UIImage? {
            let renderer = ImageRenderer(content: PlanNumberBadge(number: number, isCustom: isCustom))
            // SDK가 심볼을 @2x 기준으로 해석한다 — 화면 배율(3x)로 구우면 1.5배 커진다.
            // 24pt 뱃지가 3x에서 34.3pt로 렌더되는 걸 실측해 확인했다(2026-08-02).
            renderer.scale = 2
            return renderer.uiImage
        }

        // MARK: 카메라

        private func fitCamera(on mapView: KakaoMap, completion: @escaping () -> Void) {
            let update: CameraUpdate
            switch (points.count, regionCamera) {
            case (0, let region?):
                // 담긴 장소가 아직 없는 플랜 — 어디로 가는 계획인지만 보여 준다.
                update = CameraUpdate.make(
                    target: MapPoint(longitude: region.longitude, latitude: region.latitude),
                    zoomLevel: region.zoomLevel,
                    mapView: mapView
                )
            case (0, nil):
                // 맞출 자리가 없다. 카메라를 건드리지 않고 넘어간다.
                return completion()
            case (1, _):
                update = CameraUpdate.make(target: points[0], zoomLevel: 14, mapView: mapView)
            default:
                update = CameraUpdate.make(area: AreaRect(points: points))
            }
            mapView.moveCamera(update) { completion() }
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
            placeLogo(on: mapView)
        }

        /// 카카오 로고는 **가려도 지워도 안 되는 필수 표기**다(카카오맵 이용약관).
        ///  지도 뷰의 좌하단에 고정한다 — 시트 높이와 무관하다.
        ///
        ///  ⚠️ `setMargins`(카메라를 시트 위 영역에만 맞추려고 준다)는 카메라뿐 아니라 **GUI 배치
        ///     기준까지 함께 안쪽으로 당긴다.** 그래서 로고가 마진만큼 떠올라 시트 바로 위에 붙었다.
        ///     마진 값을 빼서 실제 뷰 하단으로 되돌린다. 카메라용 마진과 로고 위치를 따로 줄 수 있는
        ///     API가 없어(`CameraUpdate.make(area:)`에 패딩 인자가 없다) 이렇게 상쇄한다.
        private func placeLogo(on mapView: KakaoMap) {
            mapView.setLogoPosition(
                origin: GuiAlignment(vAlign: .bottom, hAlign: .left),
                position: CGPoint(x: 12, y: 48 - bottomInset)
            )
        }
    }
}
