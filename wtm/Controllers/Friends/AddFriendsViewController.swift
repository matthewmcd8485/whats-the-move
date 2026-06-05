//
//  AddFriendsViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import Contacts
import ContactsUI
import PhoneNumberKit

class AddFriendsViewController: UIViewController, UITextFieldDelegate, CNContactPickerDelegate {

    @IBOutlet weak var phoneNumberField: PhoneNumberTextField!
    @IBOutlet weak var searchButtonView: UIButton!
    @IBOutlet weak var contactsButtonView: UIButton!
    
    let alertManager = AlertManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()

        phoneNumberField.withPrefix = true
        phoneNumberField.withExamplePlaceholder = true
        phoneNumberField.withFlag = true
        phoneNumberField.delegate = self
        
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        searchButtonView.layer.cornerRadius = 10
        contactsButtonView.layer.cornerRadius = 10
    }
    
    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Text Field Delegates
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func searchButton(_ sender: Any) {
        guard !phoneNumberField.text!.isEmpty else {
            return
        }
        
        guard let phoneNumber = UserDefaults.standard.string(forKey: "phoneNumber"), phoneNumber != phoneNumberField.text else {
            alertManager.showAlert(title: "slow your roll", message: "you can't add yourself as a friend. \n maybe try making real ones?")
            return
        }
        
        if phoneNumberField.text! == "+1" {
            alertManager.showAlert(title: "no phone number entered", message: "please enter a number before continuing.")
        } else if phoneNumberField.text!.prefix(1) != "+" {
            alertManager.showAlert(title: "incorrect formatting", message: "please include the \"+\" at the beginning of the phone number.")
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "friendVerifyViewController") as FriendVerifyViewController
            vc.phoneNumber = phoneNumberField.text!
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func importFromContacts(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "importContactsViewController") as ImportContactsViewController
        navigationController?.pushViewController(vc, animated: true)
    }

    
}

extension AddFriendsViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
