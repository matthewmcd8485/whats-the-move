//
//  DatabaseError.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/3/21.
//

import Foundation

public enum DatabaseError: Error {
    case failedToFetch
    case failedToListen
    case failedToWrite
}
