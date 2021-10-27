//
//  MyProfileViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import Firebase

class MyProfileViewController: UIViewController {
    
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
        DispatchQueue.global(qos: .background).async {
            if let savedImage = ImageStoreManager.shared.retrieveImage(forKey: "profileImage", inStorageType: .fileSystem) {
                DispatchQueue.main.async {
                    self.profileImage.image = savedImage
                    UIView.animate(withDuration: 0.5) {
                        self.profileImage.alpha = 1
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
}
