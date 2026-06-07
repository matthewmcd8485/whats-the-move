//
//  User.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import Foundation

struct User: Codable {
    
    let name: String
    let phoneNumber: String
    let uid: String
    let fcmToken: String
    let status: String
    let substatus: String
    let profileImageURL: String
    let joinedTime: String
    let explicit: Bool
    
    init(name: String, phoneNumber: String, uid: String, fcmToken: String, status: String, substatus: String, profileImageURL: String, joinedTime: String, explicit: Bool = false) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.uid = uid
        self.fcmToken = fcmToken
        self.status = status
        self.substatus = substatus
        self.profileImageURL = profileImageURL
        self.joinedTime = joinedTime
        self.explicit = explicit
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case phoneNumber = "Phone Number"
        case uid = "User Identifier"
        case fcmToken = "FCM Token"
        case status = "Status"
        case substatus = "Substatus"
        case profileImageURL = "Profile Image URL"
        case joinedTime = "Joined"
        case explicit = "Explicit"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        self.uid = try container.decode(String.self, forKey: .uid)
        self.fcmToken = try container.decode(String.self, forKey: .fcmToken)
        self.status = try container.decode(String.self, forKey: .status)
        self.substatus = try container.decode(String.self, forKey: .substatus)
        self.profileImageURL = (try? container.decode(String.self, forKey: .profileImageURL)) ?? "no url"
        self.joinedTime = try container.decode(String.self, forKey: .joinedTime)
        self.explicit = (try? container.decode(Bool.self, forKey: .explicit)) ?? false
    }
}

extension User: Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.phoneNumber == rhs.phoneNumber
    }
}
