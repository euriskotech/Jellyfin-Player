import SwiftUI

/// Round profile picture with an initial as a fallback.
struct UserAvatar: View {
    let name: String
    let imageURL: URL?
    var size: CGFloat = 80

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.accentColor.gradient)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
