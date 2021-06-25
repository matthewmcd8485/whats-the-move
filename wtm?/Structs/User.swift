//
//  User.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import Foundation

struct User {
    
    let name: String?
    let phoneNumber: String?
    let uid: String?
    let fcmToken: String?
    let status: String?
    let substatus: String?
    let profileImageURL: String?
    let joinedTime: String?
    
    init(name: String, phoneNumber: String, uid: String, fcmToken: String, status: String, substatus: String, profileImageURL: String, joinedTime: String) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.uid = uid
        self.fcmToken = fcmToken
        self.status = status
        self.substatus = substatus
        self.profileImageURL = profileImageURL
        self.joinedTime = joinedTime
    }
}

extension User: Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.phoneNumber == rhs.phoneNumber
    }
}
