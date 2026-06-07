//
//  FriendGroup.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import Foundation

struct FriendGroup: Codable {
    let name: String
    let groupID: String
    var people: [String]?
    var isDirect: Bool?

    init(name: String, groupID: String, people: [String]?, isDirect: Bool? = nil) {
        self.name = name
        self.groupID = groupID
        self.people = people
        self.isDirect = isDirect
    }

    init() {
        name = ""
        groupID = ""
        people = [String]()
        isDirect = nil
    }

    var isDirectGroup: Bool { isDirect == true }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case groupID = "Group Identifier"
        case people = "People"
        case isDirect = "Direct"
    }
}
