//
//  TabBarController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit

class TabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        selectedIndex = 2
    }
}
