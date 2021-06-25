//
//  StorageError.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import Foundation

public enum StorageErrors: Error {
    case failedToUpload
    case failedToGetDownloadURL
}
