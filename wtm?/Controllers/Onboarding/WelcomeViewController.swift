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
        
    }
    
    @IBAction func getStartedButton(_ sender: Any) {
        let alert = PMAlertController(title: "agree before continuing", description: "By using this app, you agree to abide by the rules established in the privacy policy and terms & conditions.", image: nil, style: .walkthrough)
        alert.addAction(PMAlertAction(title: "i agree", style: .default, action: {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "phoneNumberViewController") as! PhoneNumberViewController
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(PMAlertAction(title: "i do not agree", style: .cancel))
        present(alert, animated: true, completion: nil)
    }
}
