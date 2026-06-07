//
//  HomeScreenViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import FirebaseFirestore
import FirebaseRemoteConfig

class HomeScreenViewController: UIViewController {
    
    let db = Firestore.firestore()
    let alertManager = AlertManager.shared

    @IBOutlet weak var boredButtonLayer: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        boredButtonLayer.layer.cornerRadius = boredButtonLayer.frame.width / 2
    
        UIApplication.resetBadgeCount()
        
        navigationController?.viewControllers = [self]
        
        checkForNewRelease()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.resetBadgeCount()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        //configureUI()
        //loadBoredRequests()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)

    }
    
    private func checkForNewRelease() {
        let latestVersion = RemoteConfig.remoteConfig()
          .configValue(forKey: "latestVersion")
          .stringValue
        print("The app's latest version is \(latestVersion).")
        
        if !latestVersion.isEmpty && UIApplication.appVersion().compare(latestVersion, options: .numeric) == .orderedAscending {
            let alert = UIAlertController(title: "new version available", message: "\"wtm?\" v\(latestVersion) is now available on the app store. please visit the app store to update it!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ok, bet", style: .default, handler: { _ in
                let url = "https://apps.apple.com/us/app/whats-the-move/id1574130925"
                if let path = URL(string: url) {
                        UIApplication.shared.open(path, options: [:], completionHandler: nil)
                }
            }))
            alert.addAction(UIAlertAction(title: "no, screw you", style: .cancel, handler: nil))

            present(alert, animated: true)
        }
    }
    
    @IBAction func boredButton(_ sender: Any) {
        guard let groups = UserDefaults.standard.stringArray(forKey: "groupsUID") else {
            print("groups array does not exist")
            return
        }
        
        guard groups.count != 0 else {
            //alertManager.showAlert(title: "no friend groups", message: "you need to be a part of a friend group before you can send requests.\n\ngo to the \"friends\" tab to create one.")

            let alert = UIAlertController(title: "no friend groups", message: "you need to be a part of a friend group before you can send requests.\n\ngo to the \"friends\" tab to create one.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "okay", style: .cancel, handler: nil))

            present(alert, animated: true)

            return
        }

        if let sendAllDate = UserDefaults.standard.object(forKey: "sendToAllDate") as? Date {
            // Calculate the difference in times between the last two times
            if let diff = Calendar.current.dateComponents([.hour], from: sendAllDate, to: Date()).hour, diff < 2 {
                let alert = UIAlertController(title: "nice try, dingbat", message: "you're still in timeout from when you sent a mass notification to all of your friends. \n\nwe understand how sad and lonely you must be. but if your friends actually cared about you, we wouldn't be in this predicament, would we?\n\nthink about that while you wait until your timeout is over.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "yeah, i'm sad and lonely", style: .default, handler: { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }))
                present(alert, animated: true)
            } else {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(identifier: "activityViewController") as ActivityViewController
                navigationController?.pushViewController(vc, animated: true)
            }
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "activityViewController") as ActivityViewController
            navigationController?.pushViewController(vc, animated: true)
        }
        
    }
}

