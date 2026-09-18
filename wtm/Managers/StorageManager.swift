//
//  StorageManager.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import Foundation
import FirebaseStorage

// `@unchecked` because the only stored property is a Firebase Storage
// reference, which is thread-safe but not annotated as Sendable.
final class StorageManager: @unchecked Sendable {
    static let shared = StorageManager()

    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    // MARK: - Upload Profile Picture
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("profile images/\(fileName)").putData(data, metadata: nil, completion: { [weak self] metadata, error in
            
            guard let strongSelf = self else {
                return
            }
            
            guard error == nil else {
                Log.storage.error("Failed to upload picture data to firebase")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            strongSelf.storage.child("profile images/\(fileName)").downloadURL(completion: { url, error in
                guard let url = url else {
                    Log.storage.error("Failed to get download URL")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download URL returned: \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    public func downloadImageURL(imageName: String, collection: String, completion: @escaping UploadPictureCompletion) {
        storage.child("\(collection)/\(imageName).png").downloadURL { url, error in
            guard let url = url else {
                Log.storage.error("Failed to get download URL: \(error?.localizedDescription ?? "unknown error", privacy: .public)")
                completion(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            completion(.success(url.absoluteString))
        }
    }
}

// MARK: - Async/Await API
extension StorageManager {
    
    public func uploadProfilePicture(with data: Data, fileName: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            uploadProfilePicture(with: data, fileName: fileName) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func downloadImageURL(imageName: String, collection: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            downloadImageURL(imageName: imageName, collection: collection) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Static Artwork URLs

/// Caches download URLs for artwork that ships with the app rather than
/// belonging to a user — the activity images, for one.
///
/// The send flow needs the activity's URL to stamp onto each bored request, and
/// it resolved that from Storage on every send even though the file for a given
/// activity never changes. The first send of a session still pays for the
/// round-trip; the rest read it from here.
@MainActor
final class StaticImageURLCache {
    static let shared = StaticImageURLCache()

    private var urls: [String: String] = [:]
    /// In-flight lookups, so several sends started at once don't each fire
    /// their own request for the same file.
    private var pending: [String: Task<String, Error>] = [:]

    func url(imageName: String, collection: String) async throws -> String {
        let key = "\(collection)/\(imageName)"
        if let cached = urls[key] { return cached }

        if let existing = pending[key] {
            return try await existing.value
        }

        let task = Task {
            try await StorageManager.shared.downloadImageURL(imageName: imageName, collection: collection)
        }
        pending[key] = task

        defer { pending[key] = nil }
        let url = try await task.value
        urls[key] = url
        return url
    }
}
