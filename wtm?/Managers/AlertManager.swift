//
//  AlertManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import Foundation
import UIKit
import PMAlertController

final class AlertManager: UIViewController {
    static let shared = AlertManager()
    
    public func showAlert(title: String, message: String) {
        let alert2 = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert2.addAction(UIAlertAction(title: "okay", style: .default, handler: nil))
        
        
        let alert = PMAlertController(title: title, description: message, image: nil, style: .alert)
        alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
        alert.alertTitle.textColor = UIColor(named: "lightBrown")!
        
        let action = PMAlertAction(title: "okay", style: .default)
        action.tintColor = UIColor(named: "lightBlue")!
        alert.addAction(action)
        
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        keyWindow!.rootViewController?.present(alert, animated: true, completion: nil)
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
