import SwiftUI

/// 상속된 애니메이션을 끊고 상태를 즉시 반영한다.
///
/// SwiftUI 는 상위(시트 표시, `withAnimation` 등)에서 내려온 트랜잭션을 그대로 물려받는다.
/// 뷰 자체에 애니메이션 코드가 없어도 선택 상태가 스르륵 바뀌는 것은 그 때문이고,
/// 칩·체크박스처럼 **폭과 글자 굵기가 함께 바뀌는** 요소에서는 주변 요소까지 밀려 흔들린다.
/// `withAnimation(nil)` 은 트랜잭션을 비우기만 해서 상위 애니메이션이 남는 경우가 있어
/// `disablesAnimations` 로 명시적으로 끈다.
func withoutAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    return try withTransaction(transaction, body)
}

extension Set where Element: Hashable {
    /// 있으면 빼고 없으면 넣는다. 선택 토글에서 매번 같은 3줄을 쓰지 않으려고 둔다.
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}
