//
//  PushNotificationSender.swift
//  The Alliance Project
//
//  Created by Matthew McDonnell on 11/24/20.
//  Copyright © 2020 Matthew McDonnell. All rights reserved.
//

import UIKit

class PushNotificationSender {
    func sendPushNotification(to token: String, title: String, body: String, urlToImage: String) {
        let urlString = "https://fcm.googleapis.com/fcm/send"
        let url = NSURL(string: urlString)!
        
        let paramString: [String : Any] = ["to" : token,
                                           "notification" : ["title" : title, "body" : body, "badge" : 1, "sound" : "default", "category" : "CutstomPush", "mutable-content" : 1],
                                           "fcm_options" : urlToImage
        ]
        
        let request = NSMutableURLRequest(url: url as URL)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: paramString, options: [.prettyPrinted])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=AAAAtUnIAG4:APA91bH3hg77hRp5YRQ-ErBP55tl97vRapD1xDojra6njZ9xmzZqC_EqaoV-PSeD58UQMnp5ZmYIrd7184N6LbIfkK2bHQuhnz1O4hDIZhw0H2rGyzE9Esa5gTXia4mu5Vz7X5q5AnEe", forHTTPHeaderField: "Authorization")

        let task =  URLSession.shared.dataTask(with: request as URLRequest)  { (data, response, error) in
            do {
                if let jsonData = data {
                    if let jsonDataDict  = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                        NSLog("Received data:\n\(jsonDataDict))")
                    }
                }
            } catch let err as NSError {
                print(err.debugDescription)
            }
        }
        task.resume()
    }
}
