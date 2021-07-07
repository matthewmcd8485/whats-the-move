//
//  NotificationViewController.swift
//  WTM Notification Content Extension
//
//  Created by Matthew McDonnell on 7/2/21.
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    @IBOutlet var label: UILabel?
    @IBOutlet var imageView: UIImageView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
    }
    
    func didReceive(_ notification: UNNotification) {
        self.label?.text = notification.request.content.body
        
        let attachments = notification.request.content.attachments
        for attachment in attachments {
            if attachment.identifier == "image" {
                print("imageURL: ", attachment.url)
                guard let data = try? Data(contentsOf: attachment.url) else {
                    return
                }
                imageView?.image = UIImage(data: data)
            }
        }
    }

}
