//
//  EditStatusViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit

class EditStatusViewController: UIViewController {

    @IBOutlet weak var availableButtonView: UIButton!
    @IBOutlet weak var busyButtonView: UIButton!
    @IBOutlet weak var dndButtonView: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        availableButtonView.layer.cornerRadius = 25
        busyButtonView.layer.cornerRadius = 25
        dndButtonView.layer.cornerRadius = 25
        
    }

    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func availableButton(_ sender: Any) {
        UserDefaults.standard.set("available", forKey: "status")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "substatusViewController") as SubstatusViewController
        vc.status = "available"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func busyButton(_ sender: Any) {
        UserDefaults.standard.set("busy", forKey: "status")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "substatusViewController") as SubstatusViewController
        vc.status = "busy"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func doNotDisturbButton(_ sender: Any) {
        UserDefaults.standard.set("do not disturb", forKey: "status")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "substatusViewController") as SubstatusViewController
        vc.status = "do not disturb"
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

extension EditStatusViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
