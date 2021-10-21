//
//  PushNotificationSender.swift
//  The Alliance Project
//
//  Created by Matthew McDonnell on 11/24/20.
//  Copyright © 2020 Matthew McDonnell. All rights reserved.
//

import UIKit
import Alamofire

class PushNotificationSender {
    func sendPushNotification(to token: String, title: String, subtitle: String, body: String, urlToImage: String) {
        let parameters: [String: Any] = [
            "to" : token,
            "notification": [
                "title" : title,
                "subtitle": subtitle,
                "body" : body,
                "badge" : 1,
                "sound" : "default",
                "mutable-content" : 1,
                "image" : urlToImage,
                "url" : urlToImage
                
            ],
            "mutable-content" : 1,
            "apns": [
                "payload": [
                    "aps": [
                        "mutable-content": 1
                    ]
                ],
                "fcm_options": [
                    "image": urlToImage
                ]
            ],
            "url" : urlToImage
        ]
        
        let headers: HTTPHeaders = ["Authorization" : AccessKeys.httpAuthorizationKey, "content-type": "application/json"]
        
        AF.request("https://fcm.googleapis.com/fcm/send", method:.post as HTTPMethod, parameters: parameters, encoding: JSONEncoding.default, headers: headers) .responseString { response in
            print(response)
        }
    }
}
