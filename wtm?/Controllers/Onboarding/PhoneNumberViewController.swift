//
//  PhoneNumberViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import FirebaseAuth
import PhoneNumberKit

class PhoneNumberViewController: UIViewController, UITextFieldDelegate {

    let phoneNumberKit = PhoneNumberKit()
    let alertManger = AlertManager.shared
    
    @IBOutlet weak var phoneNumberField: PhoneNumberTextField!
    @IBOutlet weak var nextLabel: UILabel!
    @IBOutlet weak var arrow: UIImageView!
    @IBOutlet weak var nextButtonView: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        phoneNumberField.withPrefix = true
        phoneNumberField.withExamplePlaceholder = true
        phoneNumberField.withFlag = true
        
        phoneNumberField.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    private func createSpinnerView() {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.frame = CGRect(x: view.center.x - 10, y: nextButtonView.frame.midY, width: 20, height: 20)
        
        activityIndicator.startAnimating()
        
        nextButtonView.isHidden = true
        nextLabel.isHidden = true
        arrow.isHidden = true
        
        view.addSubview(activityIndicator)
        //spinner.hudView.frame = CGRect(x: view.center.x, y: view.center.y - 120, width: 50, height: 50)
        //spinner.show(in: view)
        
    }
    
    // MARK: - Text Field Delegates
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @IBAction func nextButton(_ sender: Any) {
        guard let phoneNumber = phoneNumberField.text else {
            return
        }
        
        if phoneNumber == "" {
            alertManger.showAlert(title: "no phone number", message: "please enter your phone number in the field.")
        } else {
            createSpinnerView()
            Auth.auth().languageCode = "en"
            
            UserDefaults.standard.set(phoneNumberField.text!, forKey: "phoneNumber")
            
            PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (verificationID, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                
                UserDefaults.standard.set(verificationID!, forKey: "verificationID")
                
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(identifier: "verificationViewController") as! VerificationViewController
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
        
    }
    
    
    
}
