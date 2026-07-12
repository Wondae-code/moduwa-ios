import SwiftUI

/// 추천 섹션의 카테고리 필터 칩 (숙소·맛집·관광지·축제·공연)
struct CategoryChip: View {
    let category: PlaceCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(category.iconName)
                    .renderingMode(.template)
                Text(category.rawValue)
                    .font(.chip14)
            }
            .foregroundStyle(isSelected ? .white : .textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? Color.deepGreen : .white)
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        CategoryChip(category: .stay, isSelected: true) {}
        CategoryChip(category: .food, isSelected: false) {}
    }
    .padding()
}
