//
//  MyProfileViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import Firebase
import PMAlertController

class MyProfileViewController: UIViewController {
    
    let profanityManager = ProfanityManager.shared
    let imageStoreManager = ImageStoreManager.shared
    let alertManager = AlertManager.shared
    let databaseManager = DatabaseManager.shared
    let db = Firestore.firestore()
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var statusBackground: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet weak var joinedLabel: UILabel!
    @IBOutlet weak var substatusLabel: UILabel!
    
    // MARK: - Override Functions
    override func viewDidLoad() {
        super.viewDidLoad()

        backgroundView.layer.cornerRadius = 25
        statusBackground.layer.cornerRadius = 25
        
        profileImage.layer.cornerRadius = 15
        
        let pictureTapGesture = UITapGestureRecognizer(target: self, action: #selector(pictureButton(_:)))
        profileImage.addGestureRecognizer(pictureTapGesture)
        profileImage.isUserInteractionEnabled = true
        
        let statusTapGesture = UITapGestureRecognizer(target: self, action: #selector(statusButton(_:)))
        statusBackground.addGestureRecognizer(statusTapGesture)
        statusBackground.isUserInteractionEnabled = true
        
        nameLabel.sizeToFit()
        
        updatePicture()
        updateInformation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        updateInformation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    @IBAction func settingsButton(_ sender: Any) {
        
    }
    
    // MARK: - Updating Information
    private func updateInformation() {
        let name = UserDefaults.standard.string(forKey: "name") ?? "johnny appleseed"
        let joinedTime = UserDefaults.standard.string(forKey: "joinedTime") ?? Date().month
        let status = UserDefaults.standard.string(forKey: "status") ?? "available"
        let substatus = UserDefaults.standard.string(forKey: "substatus") ?? "ready to mingle"
        
        nameLabel.text = name.lowercased()
        joinedLabel.text = "joined \(joinedTime.lowercased())"
        substatusLabel.text = substatus.lowercased()
        
        configureStatusUI(for: status)
    }
    
    private func configureStatusUI(for status: String) {
        statusLabel.text = status.lowercased()
        if status == "available" {
            statusLabel.textColor = .systemGreen
            statusImage.image = UIImage(systemName: "checkmark.seal")
        } else if status == "busy" {
            statusLabel.textColor = .systemYellow
            statusImage.image = UIImage(systemName: "exclamationmark.bubble")
        } else {
            statusLabel.textColor = .systemRed
            statusImage.image = UIImage(systemName: "nosign")
        }
    }
    
    @IBAction @objc func statusButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "editStatusViewController") as EditStatusViewController
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
    // MARK: - Profile Image
    private func updatePicture() {
        profileImage.alpha = 0
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let savedImage = self?.imageStoreManager.retrieveImage(forKey: "profileImage", inStorageType: .fileSystem) {
                DispatchQueue.main.async {
                    self?.profileImage.image = savedImage
                    UIView.animate(withDuration: 0.5) {
                        self?.profileImage.alpha = 1
                    }
                }
            }
        }
        profileImage.alpha = 1
    }
    
    @IBAction @objc func pictureButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "pictureEditViewController") as PictureEditViewController
        vc.completion = { [weak self] result in
            self?.profileImage.image = result
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: - Edit Name
    @IBAction func editName(_ sender: Any) {
        let alert = PMAlertController(title: "change your name", description: "16 characters max.\nremember to keep it PG, please.", image: nil, style: .alert)
        alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
        alert.alertTitle.textColor = UIColor(named: "lightBrown")!
        alert.addTextField { (textField) in
            textField?.autocapitalizationType = .none
            textField?.textColor = .black
            let placeholder = "ex. joe schmoe"
            textField!.attributedPlaceholder = NSAttributedString(string: placeholder, attributes:
                                                                    [NSAttributedString.Key.foregroundColor : UIColor.lightGray])
            textField?.placeholder = placeholder
        }
        alert.addAction(PMAlertAction(title: "save", style: .default, action: { [weak self] in
            let textField = alert.textFields[0]
            guard textField.text != nil && textField.text != "" else {
                return
            }
            
            if textField.text!.count > 16 {
                self?.alertManager.showAlert(title: "name is too long", message: "read the directions, dude.\nwe aren't trying to write a shakespeare play here.")
            } else if self!.profanityManager.checkForProfanity(in: textField.text!) {
                self?.alertManager.showAlert(title: "ok, potty mouth", message: "there are some less-than-ideal words used in your name. please make sure it is appropriate.")
            } else {
                let lowercasedName = textField.text!.lowercased()
                let whitespaceName = lowercasedName.trimmingCharacters(in: .whitespacesAndNewlines)
                self?.uploadNewName(name: whitespaceName)
            }
        }))
        alert.addAction(PMAlertAction(title: "cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func uploadNewName(name: String) {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            alertManager.showAlert(title: "error updating name", message: "there was an error loading your profile details. please try again.")
            return
        }
        
        db.collection("users").document(uid).setData([
            "Name" : name
        ], merge: true, completion: { [weak self] error in
            guard error == nil else {
                self?.alertManager.showAlert(title: "error saving name", message: "something went wrong when we tried to save your new name. please try again.")
                return
            }
            self?.nameLabel.text = name
            UserDefaults.standard.set(name, forKey: "name")
            print("name change saved! new name: \(name)")
        })
    }
}
