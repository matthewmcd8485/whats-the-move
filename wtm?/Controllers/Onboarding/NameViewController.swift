//
//  NameViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit

class NameViewController: UIViewController, UITextFieldDelegate {

    let alertManager = AlertManager.shared
    let profanityManager = ProfanityManager.shared
    
    @IBOutlet weak var nameTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    // MARK: - Text Field Delegates
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func continueButton(_ sender: Any) {
        let name = nameTextField.text ?? ""
        if name == "" {
            alertManager.showAlert(title: "no name provided", message: "please enter your name in the field.")
        } else {
            if profanityManager.checkForProfanity(in: name) {
                alertManager.showAlert(title: "bad language", message: "there are some less-than-ideal words used in your name. please make sure your name is accurate and appropriate.")
            } else {
                UserDefaults.standard.set(name, forKey: "name")
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(identifier: "finishingUpViewController") as! FinishingUpViewController
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
