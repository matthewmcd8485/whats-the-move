//
//  FriendGroup.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import Foundation

struct FriendGroup {
    let name: String
    let groupID: String
    let people: [String]?
    
    init(name: String, groupID: String, people: [String]?) {
        self.name = name
        self.groupID = groupID
        self.people = people
    }
}
