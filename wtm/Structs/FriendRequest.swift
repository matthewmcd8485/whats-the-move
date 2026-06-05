//
//  FriendRequest.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//

import Foundation

struct FriendRequest {
    let name: String
    let uid: String
    let profileImageURL: String
    
    init(name: String, uid: String, profileImageURL: String) {
        self.name = name
        self.uid = uid
        self.profileImageURL = profileImageURL
    }
}
