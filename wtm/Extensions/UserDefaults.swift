//
//  UserDefaults.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/9/21.
//

import Foundation

extension UserDefaults {
    static func resetDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}
