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
}
