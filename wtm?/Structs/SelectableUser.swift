//
//  SelectableUser.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/25/21.
//

import Foundation

struct SelectableUser {
    
    let user: User
    var isSelected: Bool
    
    init(user: User, isSelected: Bool) {
        self.user = user
        self.isSelected = isSelected
    }
}

extension SelectableUser: Equatable {
    static func == (lhs: SelectableUser, rhs: SelectableUser) -> Bool {
        return lhs.user.uid == rhs.user.uid
    }
}
