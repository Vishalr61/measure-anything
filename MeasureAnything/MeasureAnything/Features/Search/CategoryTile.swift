import SwiftUI

struct CategoryTile: View {
    let icon: String
    let name: String
    let fullName: String
    let count: Int
    let tileBg: Color
    let tileIcon: Color
    let tileBorder: Color
    let tileText: Color
    let countText: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(tileIcon)
                    )

                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tileText)
                    .lineLimit(1)

                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(countText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(tileBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tileBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(fullName), \(count) units")
    }
}
