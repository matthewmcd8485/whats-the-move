//
//  PictureEditViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import Firebase

class PictureEditViewController: UIViewController {
    
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var savingLabel: UILabel!
    
    public var completion: ((UIImage) -> (Void))?
    
    let uid = UserDefaults.standard.string(forKey: "uid")!
    
    let db = Firestore.firestore()
    
    // MARK: - Override Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        savingLabel.isHidden = true
        
        updateImageView()
        
        profileImage.layer.cornerRadius = profileImage.frame.width / 2
        profileImage.clipsToBounds = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSelectProfileImageView))
        profileImage.addGestureRecognizer(tapGesture)
        profileImage.isUserInteractionEnabled = true
        
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        updateImageView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        updateImageView()
    }
    
    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    func updateImageView() {
        DispatchQueue.global(qos: .background).async {
            if let savedImage = ImageStoreManager.shared.retrieveImage(forKey: "profileImage", inStorageType: .fileSystem) {
                DispatchQueue.main.async {
                    self.profileImage.image = savedImage
                }
            }
        }
    }
    
    // MARK: - Saving Image
    @IBAction func saveButton(_ sender: Any) {
        savingLabel.isHidden = false
        savingLabel.text = "saving..."
        savingLabel.textColor = UIColor(named: "secondaryLabelColors")
        
        let image = self.profileImage.image
        if let uploadData = UIImage.pngData(image!)() {
            StorageManager.shared.uploadProfilePicture(with: uploadData, fileName: "\(uid) - profile image.png", completion: { [weak self] result in
                
                switch result {
                case .success(let url):
                    UserDefaults.standard.set(url, forKey: "profileImageURL")
                    self?.db.collection("users").document(self!.uid).setData([ "Profile Image URL": "\(url)"], merge: true)
                    if let imageToSave = self?.profileImage.image {
                        DispatchQueue.global(qos: .background).async {
                            ImageStoreManager.shared.store(image: imageToSave, forKey: "profileImage", withStorageType: .fileSystem)
                            print("image saved to device!")
                        }
                    }
                    self?.showSavedImageCompletion()
                case .failure(let error):
                    AlertManager.shared.showAlert(title: "Error uploading image", message: "There was an error saving your new image to the database. Please try again. \n \n Error: \(error)")
                    print("Error uploading placeholder profile picture to Firebase: \(error)")
                }
            })
        }
    }
    
    func showSavedImageCompletion() {
        savingLabel.text = "image saved!"
        savingLabel.textColor = .systemGreen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            self.completion!(self.profileImage.image!)
            self.navigationController?.popViewController(animated: true)
        })
    }
}

extension PictureEditViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
