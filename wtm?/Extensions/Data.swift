//
//  Data.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/2/21.
//

import Foundation

extension Data {
    var hexString: String {
        let hexString = map {
            String(format: "%02.2hhx", $0)
        }.joined()
        return hexString
    }
}
