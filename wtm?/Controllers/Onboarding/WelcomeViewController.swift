//
//  WelcomeViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import PMAlertController

class WelcomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //navigationController?.viewControllers = [self]
        
        //if let viewControllerCount = navigationController?.viewControllers.count {
        //    navigationController?.viewControllers.removeFirst(viewControllerCount - 1)
        //}
        
        //print(navigationController?.viewControllers)
    }
    
    @IBAction func getStartedButton(_ sender: Any) {
        let alert = PMAlertController(title: "agree before continuing", description: "by using this app, you agree to abide by the rules established in the privacy policy and terms & conditions.", image: nil, style: .walkthrough)
        alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
        alert.addAction(PMAlertAction(title: "i agree", style: .default, action: { [weak self] in
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "phoneNumberViewController") as! PhoneNumberViewController
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(PMAlertAction(title: "privacy policy", style: .cancel, action: {
            guard let url = URL(string: "https://matthewdevteam.weebly.com/privacy.html") else { return }
            UIApplication.shared.open(url)
        }))
        alert.addAction(PMAlertAction(title: "terms", style: .cancel, action: {
            guard let url = URL(string: "https://matthewdevteam.weebly.com/terms-and-conditions.html") else { return }
            UIApplication.shared.open(url)
        }))
        alert.addAction(PMAlertAction(title: "i do not agree", style: .cancel))
        present(alert, animated: true, completion: nil)
    }
}
