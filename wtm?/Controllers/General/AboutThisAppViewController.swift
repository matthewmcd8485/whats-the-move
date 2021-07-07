//
//  AboutThisAppViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit

class AboutThisAppViewController: UIViewController {
    
    let alertManager = AlertManager.shared

    @IBOutlet weak var reviewButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        reviewButton.layer.cornerRadius = 10
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func reviewButton(_ sender: Any) {
        alertManager.showAlert(title: "slow your roll", message: "we appreciate how much you love us. but you can't write a review on the app until it's on the app store. \n\nmaybe try doing someting more productive while you wait?")
    }
}

extension AboutThisAppViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
