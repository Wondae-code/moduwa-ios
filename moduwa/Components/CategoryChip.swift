import SwiftUI

/// 추천 섹션의 카테고리 필터 칩 (숙소·맛집·관광지·축제·공연)
struct CategoryChip: View {
    let category: PlaceCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(category.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                Text(category.rawValue)
                    .font(.pretendard(14, isSelected ? .bold : .regular))
            }
            .foregroundStyle(isSelected ? Color.white : .textSecondary)
            .padding(.horizontal, 15)
            .frame(height: 36)
            .background(
                Capsule().fill(isSelected ? Color.deepGreen : .white)
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.deepGreen : .cardStroke, lineWidth: 1)
            )
            .shadow(color: isSelected ? .deepGreen.opacity(0.18) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        CategoryChip(category: .stay, isSelected: true) {}
        CategoryChip(category: .food, isSelected: false) {}
        CategoryChip(category: .attraction, isSelected: false) {}
    }
    .padding()
}
