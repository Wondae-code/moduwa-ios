import SwiftUI

/// 피그마에서 추출한 ISA(국제 접근성 심볼) 휠체어 아이콘.
/// 템플릿 이미지라 foregroundStyle로 색을 입힌다.
struct ISAWheelchairIcon: View {
    var size: CGFloat = 12

    var body: some View {
        Image("ISAWheelchair")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 12) {
        ISAWheelchairIcon(size: 12).foregroundStyle(.deepGreen)
        ISAWheelchairIcon(size: 24).foregroundStyle(.deepGreen)
        ISAWheelchairIcon(size: 40).foregroundStyle(.white)
            .padding(8)
            .background(Circle().fill(Color.deepGreen))
    }
    .padding()
}
