//
//  ImageStoreManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import Foundation
import UIKit

final class ImageStoreManager {
    static let shared = ImageStoreManager()
    
    public func filePath(forKey key: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentURL = fileManager.urls(for: .documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first else { return nil }
        
        return documentURL.appendingPathComponent(key + ".png")
    }
    
    public func store(image: UIImage, forKey key: String) {
        guard let pngRepresentation = image.pngData(),
              let filePath = filePath(forKey: key) else { return }
        do {
            try pngRepresentation.write(to: filePath, options: .atomic)
        } catch let err {
            print("Saving file resulted in error: ", err)
        }
    }
    
    public func retrieveImage(forKey key: String) -> UIImage? {
        guard let filePath = self.filePath(forKey: key),
              let fileData = FileManager.default.contents(atPath: filePath.path) else { return nil }
        return UIImage(data: fileData)
    }
}
