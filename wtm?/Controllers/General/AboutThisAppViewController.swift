//
//  AboutThisAppViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit

class AboutThisAppViewController: UIViewController {

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
        
    }
}

extension AboutThisAppViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
