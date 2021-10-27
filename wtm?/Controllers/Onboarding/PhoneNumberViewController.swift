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
    let alertManager = AlertManager.shared
    
    let activityIndicator = UIActivityIndicatorView(style: .large)
    var continuing = false
    
    @IBOutlet weak var phoneNumberField: PhoneNumberTextField!
    @IBOutlet weak var nextLabel: UILabel!
    @IBOutlet weak var arrow: UIImageView!
    @IBOutlet weak var nextButtonView: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.color = .white
        activityIndicator.frame = CGRect(x: view.center.x - 10, y: nextButtonView.frame.midY, width: 20, height: 20)
        view.addSubview(activityIndicator)
        activityIndicator.isHidden = true
        
        phoneNumberField.withPrefix = true
        phoneNumberField.withExamplePlaceholder = true
        phoneNumberField.withFlag = true
        
        phoneNumberField.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    private func createSpinnerView() {
        activityIndicator.startAnimating()
        
        activityIndicator.isHidden = false
        nextButtonView.isHidden = true
        nextLabel.isHidden = true
        arrow.isHidden = true
    }
    
    private func dismissSpinnerView() {
        activityIndicator.stopAnimating()
        
        activityIndicator.isHidden = true
        nextButtonView.isHidden = false
        nextLabel.isHidden = false
        arrow.isHidden = false
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if !strongSelf.continuing {
                strongSelf.alertManager.showAlert(title: "loading error", message: "something went wrong here. check your internet connection and try again.")
                strongSelf.dismissSpinnerView()
                return
            }
        }
        
        if phoneNumber == "" {
            alertManager.showAlert(title: "no phone number", message: "please enter your phone number in the field.")
        } else {
            createSpinnerView()
            Auth.auth().languageCode = "en"
            
            UserDefaults.standard.set(phoneNumberField.text!, forKey: "phoneNumber")
            
            PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] (verificationID, error) in
                if let error = error {
                    print(error.localizedDescription)
                    self?.alertManager.showAlert(title: "loading error", message: "something went wrong here. check your internet connection and try again.")
                    self?.dismissSpinnerView()
                    return
                }
                
                self?.continuing = true
                UserDefaults.standard.set(verificationID!, forKey: "verificationID")
                
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(identifier: "verificationViewController") as! VerificationViewController
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        }
        
    }
    
    
    
}
