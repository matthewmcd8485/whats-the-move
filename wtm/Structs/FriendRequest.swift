//
//  FriendRequest.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//

import Foundation

struct FriendRequest: Codable {
    let name: String
    let uid: String
    let profileImageURL: String
    
    init(name: String, uid: String, profileImageURL: String) {
        self.name = name
        self.uid = uid
        self.profileImageURL = profileImageURL
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case uid = "User Identifier"
        case profileImageURL = "Profile Image URL"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.uid = try container.decode(String.self, forKey: .uid)
        self.profileImageURL = (try? container.decode(String.self, forKey: .profileImageURL)) ?? "no url"
    }
}
