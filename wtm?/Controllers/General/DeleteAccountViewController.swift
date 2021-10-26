//
//  DeleteAccountViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 10/25/21.
//

import UIKit
import Firebase
import FirebaseAuthUI
import PMAlertController

class DeleteAccountViewController: UIViewController {

    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var deleteButtonLayer: UIButton!
    @IBOutlet weak var workingLabel: UILabel!
    
    let db = Firestore.firestore()
    let auth = Auth.auth()
    let alertManager = AlertManager.shared
    let activityIndicator = UIActivityIndicatorView(style: .large)
        
    override func viewDidLoad() {
        super.viewDidLoad()

        cancelButton.layer.cornerRadius = 10
        deleteButtonLayer.titleLabel?.textAlignment = .center
        
        activityIndicator.color = .white
        activityIndicator.frame = CGRect(x: view.center.x - 10, y: cancelButton.frame.midY - 10, width: 20, height: 20)
        view.addSubview(activityIndicator)
        removeSpinnerView()
       
    }
    
    private func showSpinnerView() {
        activityIndicator.startAnimating()
        
        workingLabel.isHidden = false
        activityIndicator.isHidden = false
        cancelButton.layer.isHidden = true
        deleteButtonLayer.layer.isHidden = true
    }
    
    private func removeSpinnerView() {
        activityIndicator.stopAnimating()
        
        cancelButton.layer.isHidden = false
        deleteButtonLayer.layer.isHidden = false
        activityIndicator.isHidden = true
        workingLabel.isHidden = true
    }

    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func deleteButton(_ sender: Any) {
        showSpinnerView()
        
        guard let phoneNumber = UserDefaults.standard.string(forKey: "phoneNumber") else {
            return
        }
        
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] (verificationID, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            self?.reauthenticate(verificationID: verificationID!)
        }
    }
    
    private func reauthenticate(verificationID: String) {
        let user = auth.currentUser
        
        let alert = PMAlertController(title: "check your messages", description: "you need to verify your identity before we can delete your account.\n\n enter the verification code we sent to the phone number associated with your account.", image: nil, style: .alert)
        alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
        alert.alertTitle.textColor = UIColor(named: "lightBrown")!
        alert.addTextField { (textField) in
            textField?.autocapitalizationType = .none
            textField?.keyboardType = .phonePad
            let placeholder = "ex. 123456"
            textField!.attributedPlaceholder = NSAttributedString(string: placeholder, attributes:
                                                                    [NSAttributedString.Key.foregroundColor : UIColor.lightGray])
            textField?.placeholder = placeholder
        }
        alert.addAction(PMAlertAction(title: "continue", style: .default, action: { [weak self] in
            let textField = alert.textFields[0]
            guard textField.text != nil && textField.text != "" else {
                return
            }
            
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: textField.text!)
            
            user?.reauthenticate(with: credential) { result, error in
                guard error == nil else {
                    print("Error reauthenticating user: \(error!)")
                    return
                }
                self?.removeFirestoreData()
            }
        }))
        alert.addAction(PMAlertAction(title: "cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func removeFirestoreData() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            print("No UID found")
            return
        }
        
        // Clear out Firestore Profile
        db.collection("users").document(uid).setData([
            "Name" : "user deleted",
            "Phone Number" : "user deleted",
            "Profile Image URL" : "user deleted",
            "Joined" : "user deleted",
            "FCM Token" : "user deleted",
            "Status" : "user deleted",
            "Substatus" : "user deleted"
        ], merge: true, completion: { [weak self] error in
            guard error == nil else {
                print("Error deleting user's Firestore profole: \(error!)")
                return
            }
            print("Firestore profile cleared!")
            
            // Clear friend's references
            self?.db.collectionGroup("friends").whereField("User Identifier", isEqualTo: uid).getDocuments { (snapshot, error) in
                guard error == nil else {
                    print("Error retrieving collection group documents: \(error!)")
                    return
                }
                
                for document in snapshot!.documents {
                    document.reference.setData([
                        "Name" : "user deleted"
                    ], merge: true, completion: { error in
                        guard error == nil else {
                            print("Error renaming friend document in Firestore: \(error!)")
                            return
                        }
                    })
                }
                
                print("Data cleared!")
                
                let user = self?.auth.currentUser
                user?.delete { error in
                    if let error = error {
                        print("Error deleting Auth user: \(error)")
                    } else {
                        self?.goToLoadingScreen()
                    }
                }
            }
        })
    }
    
    private func goToLoadingScreen() {
        navigationController?.viewControllers = [self]
        tabBarController?.viewControllers = [self]
        UserDefaults.resetDefaults()
        UserDefaults.standard.set(true, forKey: "launchedBefore")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "loadingViewController") as LoadingViewController
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension DeleteAccountViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
