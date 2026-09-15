//
//  PhoneNumberFieldView.swift
//  wtm?
//
//  Wraps PhoneNumberKit's `PhoneNumberTextField` for SwiftUI.
//
//  The onboarding phone step relies on that class for the country flag, the
//  dialling prefix, the country-specific example placeholder, and live
//  reformatting as digits are typed. Reimplementing that on a plain `TextField`
//  would mean reimplementing international phone formatting, so the UIKit view
//  is kept and bridged instead.
//

import SwiftUI
import PhoneNumberKit

struct PhoneNumberFieldView: UIViewRepresentable {
    @Binding var text: String
    /// Called when the keyboard's return key is pressed.
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> PhoneNumberTextField {
        let field = PhoneNumberTextField()

        // Matches the previous storyboard configuration.
        field.withPrefix = true
        field.withFlag = true
        field.withExamplePlaceholder = true

        field.font = UIFont(name: Font.WTM.thin, size: 25)
        field.textColor = UIColor(named: "darkBlueOnLight")
        field.tintColor = UIColor(named: "darkBlueOnLight")
        field.backgroundColor = .clear
        field.borderStyle = .none
        // The storyboard field was textAlignment="center" across its full width.
        field.textAlignment = .center
        field.keyboardType = .phonePad
        field.textContentType = .telephoneNumber
        field.adjustsFontForContentSizeCategory = true

        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ field: PhoneNumberTextField, context: Context) {
        context.coordinator.parent = self
        // Only write back when the values genuinely differ, otherwise assigning
        // `text` fights the field's own live formatting and moves the caret.
        if field.text != text {
            field.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PhoneNumberFieldView

        init(parent: PhoneNumberFieldView) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onSubmit()
            return false
        }
    }
}
