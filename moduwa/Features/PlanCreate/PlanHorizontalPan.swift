import SwiftUI
import UIKit

/// **가로로 움직일 때만** 시작하는 팬 인식기. 세로 스크롤은 그대로 살린다.
///
/// ⚠️ **SwiftUI `DragGesture` 로는 안 된다.** 세로 `ScrollView` 안에서 `simultaneousGesture`
/// 로 붙여도, 그 제스처가 **활성화되는 순간 스크롤 뷰의 팬을 먹어** 달력이 스크롤되지 않는다
/// (2026-09-07 실측). 그래서 관례가 "꾹 누른 뒤 끌기" 인데, 누르고 기다리는 게 답답하다는
/// 요청이 있었다. UIKit 으로 내려오면 두 가지를 직접 정할 수 있다:
///
/// - `gestureRecognizerShouldBegin` — **가로가 우세할 때만** 시작한다. 세로로 훑으면 아예
///   시작하지 않으므로 스크롤이 온전히 살아 있다.
/// - `shouldRecognizeSimultaneouslyWith` — 스크롤 뷰의 팬과 동시 인식을 허용한다.
/// - `cancelsTouchesInView = false` — 아래 날짜 칸의 탭이 그대로 살아 있다.
///
/// 인식기는 **감싸고 있는 스크롤 뷰에 붙인다.** 이 뷰에 붙이면 터치를 이 뷰가 가로채
/// 버튼들이 탭을 못 받는다(`hitTest` 로 통과시키면 인식기도 터치를 못 받는다).
struct PlanHorizontalPan: UIViewRepresentable {
    /// 손이 처음 닿은 곳과 지금 있는 곳 — 둘 다 이 뷰(격자)의 좌표계다.
    var onChange: (_ origin: CGPoint, _ location: CGPoint) -> Void
    var onEnd: () -> Void

    func makeUIView(context: Context) -> UIView {
        // ⚠️ **창에 올라온 뒤에 붙여야 한다.** `updateUIView` 가 처음 불릴 때는 상위 뷰
        //  사슬이 아직 이어지지 않아 스크롤 뷰를 못 찾는다(실측: 팬이 아예 안 걸렸다).
        let view = HostView { [weak coordinator = context.coordinator] host in
            coordinator?.attach(from: host)
        }
        view.backgroundColor = .clear
        // 터치를 가로채지 않는다 — 인식기는 `attach` 에서 스크롤 뷰에 붙는다.
        view.isUserInteractionEnabled = false
        context.coordinator.reference = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onEnd = onEnd
        context.coordinator.attach(from: uiView)
    }

    /// 창에 올라오는 순간을 알려 주는 것 말고는 하는 일이 없다.
    final class HostView: UIView {
        private let onMoveToWindow: (UIView) -> Void

        init(onMoveToWindow: @escaping (UIView) -> Void) {
            self.onMoveToWindow = onMoveToWindow
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { onMoveToWindow(self) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: ((CGPoint, CGPoint) -> Void)?
        var onEnd: (() -> Void)?
        /// 좌표를 재는 기준 — 격자 컨테이너 그 자체다.
        weak var reference: UIView?
        private weak var host: UIScrollView?
        private lazy var pan: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handle))
            pan.delegate = self
            // 아래 날짜 칸의 탭을 죽이지 않는다.
            pan.cancelsTouchesInView = false
            return pan
        }()

        /// 감싸고 있는 스크롤 뷰를 찾아 인식기를 한 번만 붙인다.
        func attach(from view: UIView) {
            guard host == nil else { return }
            var next = view.superview
            while let candidate = next {
                if let scroll = candidate as? UIScrollView {
                    scroll.addGestureRecognizer(pan)
                    host = scroll
                    return
                }
                next = candidate.superview
            }
        }

        @objc private func handle(_ gesture: UIPanGestureRecognizer) {
            guard let reference else { return }
            switch gesture.state {
            case .began, .changed:
                let location = gesture.location(in: reference)
                let translation = gesture.translation(in: reference)
                // 손이 **처음 닿은 곳**은 지금 위치에서 이동량을 뺀 값이다. 인식기는 10pt쯤
                //  움직인 뒤에 시작하므로, 그냥 현재 위치를 쓰면 출발 칸을 지나칠 수 있다.
                let origin = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
                onChange?(origin, location)
            case .ended, .cancelled, .failed:
                onEnd?()
            default:
                break
            }
        }

        /// **가로가 우세할 때만** 시작한다 — 세로로 훑으면 스크롤에 온전히 넘긴다.
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let pan = gesture as? UIPanGestureRecognizer, let view = pan.view
            else { return false }
            let velocity = pan.velocity(in: view)
            let translation = pan.translation(in: view)
            // 느리게 시작하면 속도가 0 에 가깝다 — 이동량도 함께 본다.
            let horizontal = abs(velocity.x) + abs(translation.x) * 4
            let vertical = abs(velocity.y) + abs(translation.y) * 4
            return horizontal > vertical
        }

        func gestureRecognizer(
            _ gesture: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}
