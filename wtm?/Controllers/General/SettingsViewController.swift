//
//  SettingsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import Firebase
import PMAlertController

class SettingsViewController: UIViewController {

    let auth = Auth.auth()
    let alertManager = AlertManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        tabBarController?.hidesBottomBarWhenPushed = true
    }

    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func logOutButton(_ sender: Any) {
        let alert = PMAlertController(title: "log out", description: "are you sure you want to log out?", image: nil, style: .alert)
        alert.addAction(PMAlertAction(title: "cancel", style: .cancel))
        alert.addAction(PMAlertAction(title: "log out", style: .default, action: {
            do {
                try self.auth.signOut()
            } catch {
                print("Sign out process failed")
                self.alertManager.showAlert(title: "sign out failed", message: "there was an error logging you out. please try again.")
            }
            
            UserDefaults.resetDefaults()
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "loadingViewController") as LoadingViewController
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        present(alert, animated: true)
    }
}

extension SettingsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
