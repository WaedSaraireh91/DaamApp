import SwiftUI
import UIKit

/// Makes input and placeholder alignment deterministic in both app languages.
struct LocalizedTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    @Environment(\.layoutDirection) private var direction

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.borderStyle = .none
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text { field.text = text }
        if field.isSecureTextEntry != secure { field.isSecureTextEntry = secure }
        field.keyboardType = keyboard
        field.autocapitalizationType = keyboard == .emailAddress || secure ? .none : .sentences
        field.autocorrectionType = keyboard == .emailAddress || secure ? .no : .default
        field.textContentType = secure ? .password : keyboard == .emailAddress ? .emailAddress : nil
        let rtl = direction == .rightToLeft
        field.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        field.textAlignment = rtl ? .right : .left
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = rtl ? .right : .left
        paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraph,
            .font: UIFont.preferredFont(forTextStyle: .body)
        ])
        field.accessibilityLabel = placeholder
        if let range = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument) {
            field.setBaseWritingDirection(rtl && keyboard != .emailAddress ? .rightToLeft : .leftToRight, for: range)
        }
    }
    final class Coordinator: NSObject {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        @objc func changed(_ field: UITextField) { text.wrappedValue = field.text ?? "" }
    }
}
