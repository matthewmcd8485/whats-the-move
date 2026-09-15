//
//  String.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/27/21.
//

import Foundation

extension String {
    func trimTrailingWhitespace() -> String {
        if let trailingWs = self.range(of: "\\s+$", options: .regularExpression) {
            return self.replacingCharacters(in: trailingWs, with: "")
        } else {
            return self
        }
    }

    /// Alphabetical ordering for names shown in a list.
    ///
    /// `<` on `String` compares Unicode scalars, which puts every capital
    /// letter ahead of every lowercase one — a friend saved as "Zoe" landed
    /// above "adam". Names are lowercased when they're entered here, but
    /// accounts created before that, and names that came in from elsewhere,
    /// still carry capitals. `localizedStandardCompare` is the Finder-style
    /// comparison: case- and diacritic-insensitive, and locale-aware.
    func sortsBefore(_ other: String) -> Bool {
        localizedStandardCompare(other) == .orderedAscending
    }
}
