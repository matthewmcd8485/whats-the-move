//
//  GroupNotification.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/20/21.
//

import Foundation

struct GroupNotification {
    var group: FriendGroup
    var people: [User]
    
    init(group: FriendGroup, people: [User]) {
        self.group = group
        self.people = people
    }
}
