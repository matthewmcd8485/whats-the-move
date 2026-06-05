//
//  Int.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import Foundation

extension Int: Sequence {
    public func makeIterator() -> CountableRange<Int>.Iterator {
        return (0..<self).makeIterator()
    }
}
