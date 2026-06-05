//
//  WelcomeViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit

class WelcomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set("No profile image yet", forKey: "profileImageURL")
        
        //navigationController?.viewControllers = [self]
        
        //if let viewControllerCount = navigationController?.viewControllers.count {
        //    navigationController?.viewControllers.removeFirst(viewControllerCount - 1)
        //}
        
        //print(navigationController?.viewControllers)
    }
    
    @IBAction func getStartedButton(_ sender: Any) {
        let alert = UIAlertController(title: "agree before continuing", message: "by using this app, you agree to abide by the rules established in the privacy policy and terms & conditions.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "i agree", style: .default, handler: { [weak self] _ in
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "phoneNumberViewController") as! PhoneNumberViewController
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "privacy policy", style: .cancel, handler: { _ in
            guard let url = URL(string: "https://matthewdevteam.weebly.com/privacy.html") else { return }
            UIApplication.shared.open(url)
        }))
        alert.addAction(UIAlertAction(title: "terms", style: .cancel, handler: { _ in
            guard let url = URL(string: "https://matthewdevteam.weebly.com/terms-and-conditions.html") else { return }
            UIApplication.shared.open(url)
        }))
        alert.addAction(UIAlertAction(title: "i do not agree", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
