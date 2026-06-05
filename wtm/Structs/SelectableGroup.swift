//
//  SelectableGroup.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/26/21.
//

import Foundation

struct SelectableGroup {
    
    let group: FriendGroup
    let friends: [Friend]
    var isSelected: Bool
    
    init(group: FriendGroup, friends: [Friend], isSelected: Bool) {
        self.group = group
        self.friends = friends
        self.isSelected = isSelected
    }
}

extension SelectableGroup: Equatable {
    static func == (lhs: SelectableGroup, rhs: SelectableGroup) -> Bool {
        return lhs.group.groupID == rhs.group.groupID
    }
}
