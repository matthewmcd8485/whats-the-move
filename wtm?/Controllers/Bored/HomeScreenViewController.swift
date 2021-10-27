//
//  HomeScreenViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import Firebase
import PMAlertController

class HomeScreenViewController: UIViewController {
    
    let db = Firestore.firestore()
    let alertManager = AlertManager.shared

    @IBOutlet weak var boredButtonLayer: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        boredButtonLayer.layer.cornerRadius = boredButtonLayer.frame.width / 2
    
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        navigationController?.viewControllers = [self]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.applicationIconBadgeNumber = 0

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
    
    @IBAction func boredButton(_ sender: Any) {
        guard let groups = UserDefaults.standard.stringArray(forKey: "groupsUID") else {
            print("groups array does not exist")
            return
        }
        
        guard groups.count != 0 else {
            //alertManager.showAlert(title: "no friend groups", message: "you need to be a part of a friend group before you can send requests.\n\ngo to the \"friends\" tab to create one.")
            
            let alert = PMAlertController(title: "no friend groups", description: "you need to be a part of a friend group before you can send requests.\n\ngo to the \"friends\" tab to create one.", image: nil, style: .alert)
            alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
            alert.addAction(PMAlertAction(title: "okay", style: .cancel))
         //   alert.addAction(PMAlertAction(title: "take me there", style: .default, action: { [weak self] in
         //       self?.tabBarController?.selectedIndex = 0
         //   }))
            
            present(alert, animated: true)
            
            return
        }
        
        if let sendAllDate = UserDefaults.standard.object(forKey: "sendToAllDate") as? Date {
            // Calculate the difference in times between the last two times
            if let diff = Calendar.current.dateComponents([.hour], from: sendAllDate, to: Date()).hour, diff < 2 {
                let alert = PMAlertController(title: "nice try, dingbat", description: "you're still in timeout from when you sent a mass notification to all of your friends. \n\nwe understand how sad and lonely you must be. but if your friends actually cared about you, we wouldn't be in this predicament, would we?\n\nthink about that while you wait until your timeout is over.", image: nil, style: .alert)
                alert.alertTitle.font = UIFont(name: "SuperBasic-Bold", size: 25)
                alert.alertTitle.textColor = UIColor(named: "lightBrown")!
                alert.addAction(PMAlertAction(title: "yeah, i'm sad and lonely", style: .default, action: { [weak self] in
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

