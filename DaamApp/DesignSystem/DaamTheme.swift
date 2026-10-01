import SwiftUI

enum DaamTheme {
    static let background = Color("Background")
    static let authBackground = Color("AuthBackground")
    static let primary = Color("AccentColor")
    static let authPrimary = Color("AuthPrimary")
    static let text = Color("PrimaryText")
    static let secondary = Color("SecondaryText")
    static let border = Color("Border")
    static let gold = Color("Rating")
}

struct DaamButtonStyle: ButtonStyle {
    var outlined = false
    var authentication = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        let tint = authentication ? DaamTheme.authPrimary : DaamTheme.primary
        configuration.label
            .font(.callout.weight(.bold))
            .frame(maxWidth: .infinity).frame(minHeight: 52)
            .foregroundStyle(outlined ? tint : .white)
            .background(outlined ? .white : tint, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(outlined ? tint : .clear, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}

extension View {
    func daamCard(radius: CGFloat = 16) -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(DaamTheme.primary.opacity(0.16), lineWidth: 1))
    }
    func daamScreen(framed: Bool = true) -> some View {
        modifier(DaamPageSurface(framed: framed))
            .foregroundStyle(DaamTheme.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DaamTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// One fixed page outline around the entire viewport, independent of scrolling.
struct DaamPageSurface: ViewModifier {
    var framed = true
    func body(content: Content) -> some View {
        if framed {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(DaamTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(DaamTheme.primary.opacity(0.34), lineWidth: 1.5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .shadow(color: DaamTheme.primary.opacity(0.05), radius: 8, y: 3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color("Mint").opacity(0.45).ignoresSafeArea())
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(DaamTheme.background)
        }
    }
}

struct Field: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var secure = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.bold))
            LocalizedTextField(placeholder: placeholder, text: $text, secure: secure, keyboard: secure ? .default : .emailAddress)
                .frame(height: 26).padding(.horizontal, 16).frame(minHeight: 52)
                .daamCard(radius: 14)
            .accessibilityLabel(title)
        }
    }
}
