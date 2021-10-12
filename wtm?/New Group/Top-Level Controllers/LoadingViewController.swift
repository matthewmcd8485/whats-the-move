//
//  ViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import Firebase

class LoadingViewController: UIViewController {

    @IBOutlet weak var loadingLabel: UILabel!
    let databaseManager = DatabaseManager.shared
    let reportingManager = ReportingManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController?.hidesBottomBarWhenPushed = true
        
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        createSpinnerView()
        showLoginIfNecessary()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        navigationController?.navigationBar.backItem?.backBarButtonItem?.tintColor = UIColor(named: "purpleColor")
    }
    
    private func createSpinnerView() {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.frame = CGRect(x: view.center.x - 10, y: loadingLabel.frame.maxY + 50, width: 20, height: 20)
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        //spinner.hudView.frame = CGRect(x: view.center.x, y: view.center.y - 120, width: 50, height: 50)
        //spinner.show(in: view)
        
    }
    
    // MARK: - Checking Credentials
    private func checkForLaunchHistory() -> Bool {
        let launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
        if launchedBefore {
            return true
        } else {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            return false
        }
    }
    
    private func checkForLoginHistory() -> Bool {
        if UserDefaults.standard.bool(forKey: "loggedIn") {
            return true
        }
        return false
    }
    
    private func showLoginIfNecessary() {
        let launchedBefore = checkForLaunchHistory()
        let loggedIn = checkForLoginHistory()
        
        if launchedBefore == false || loggedIn == false {
            print("User is not set up, showing login screen")
            
            // Send to login screen
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                let onboarding = storyboard.instantiateViewController(withIdentifier: "welcomeViewController") as! WelcomeViewController
                self.navigationController?.pushViewController(onboarding, animated: true)
            })
        } else {
            // Send to home screen
            self.updateFriendsList()
            self.updateFCMToken()
            self.updateGroupsList()
            
            let group = DispatchGroup()
            group.enter()
            
            let uid = UserDefaults.standard.string(forKey: "uid")
            self.databaseManager.updateBlockedUsersList(uid: uid!, completion: { success in
                print("result: \(success)")
                group.leave()
            })
            
            group.notify(queue: .main) { [weak self] in
                self?.goHome()
            }
        }
    }
    
    private func goHome() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let onboarding = storyboard.instantiateViewController(withIdentifier: "tabBarController") as! TabBarController
            self.navigationController?.pushViewController(onboarding, animated: true)
        })
    }
    
    private func updateFCMToken() {
        let uid = UserDefaults.standard.string(forKey: "uid")
        if let fcmToken = UserDefaults.standard.string(forKey: "fcmToken") {
            Messaging.messaging().token { [weak self] token, error in
                if let error = error {
                    print("Error fetching FCM registration token: \(error)")
                } else if let token = token {
                    print("FCM registration token: \(token)")
                    
                    if token != fcmToken {
                        self?.databaseManager.updateFCMToken(uid: uid!, newToken: token)
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }
    
    private func updateFriendsList() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        var uids = [String]()
        
        databaseManager.downloadAllFriends(uid: uid, completion: { result in
            switch result {
            case .success(let users):
                for x in users.count {
                    uids.append(users[x].uid)
                }
                UserDefaults.standard.set(uids, forKey: "friendsUID")
            case .failure(let error):
                print("\n *LOADING VIEW CONTROLLER* \n error downloading friend from firebase: \(error)")
            }
        })
    }
    
    private func updateGroupsList() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        var groupIDs = [String]()
        
        databaseManager.downloadAllGroups(uid: uid, completion: { result in
            switch result {
            case .success(let downloadedGroups):
                for x in downloadedGroups.count {
                    groupIDs.append(downloadedGroups[x].groupID)
                }
                UserDefaults.standard.set(groupIDs, forKey: "groupsUID")
            case .failure(let error):
                print("\n *GROUPS VIEW CONTROLLER* \n error downloading friend from firebase: \(error)")
            }
        })
    }
    
}
