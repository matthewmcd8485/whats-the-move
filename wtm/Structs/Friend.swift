//
//  Friend.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//

import Foundation

struct Friend: Codable {
    let name: String
    let uid: String
    
    init(name: String, uid: String) {
        self.name = name
        self.uid = uid
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case uid = "User Identifier"
    }
}
