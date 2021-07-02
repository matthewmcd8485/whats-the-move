//
//  HomeScreenViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit

class HomeScreenViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    @IBAction func boredButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "activityViewController") as ActivityViewController
        navigationController?.pushViewController(vc, animated: true)
    }
}
