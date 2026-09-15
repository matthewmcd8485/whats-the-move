//
//  AlertManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import Foundation
import UIKit

// Presents UIKit alerts, so the whole type belongs on the main actor. It was
// previously nonisolated and reached into UIApplication.shared / window state
// from whatever thread the caller happened to be on.
@MainActor
final class AlertManager {
    static let shared = AlertManager()

    private init() {}

    public func showAlert(title: String, message: String) {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        guard let rootViewController = keyWindow?.rootViewController else { return }

        // Walk to whatever is actually frontmost. Presenting on the root while
        // it already has something up throws "which is already presenting" and
        // silently drops the alert.
        var presenter = rootViewController
        while let presented = presenter.presentedViewController {
            // An alert is already on screen — a second one would be dropped, so
            // let the first one stand rather than queueing a duplicate.
            if presented is UIAlertController { return }
            presenter = presented
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "okay", style: .default, handler: nil))
        presenter.present(alert, animated: true, completion: nil)
    }
}

extension UIAlertAction {
    var titleTextColor: UIColor? {
        get {
            return self.value(forKey: "titleTextColor") as? UIColor
        } set {
            self.setValue(newValue, forKey: "titleTextColor")
        }
    }
}
