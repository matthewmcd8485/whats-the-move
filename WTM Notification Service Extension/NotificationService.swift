//
//  NotificationService.swift
//  WTM Notification Service Extension
//
//  Created by Matthew McDonnell on 7/2/21.
//

import UserNotifications
import UniformTypeIdentifiers
import Foundation
import os

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private static let log = Logger(subsystem: "com.matthew.wtm-", category: "push")

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // Every exit path must call contentHandler exactly once, otherwise the
        // notification isn't delivered until the system times the extension out.
        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        guard let attachmentURLAsString = bestAttemptContent.userInfo["url"] as? String,
              let attachmentURL = URL(string: attachmentURLAsString) else {
            // No image to attach — deliver the payload unmodified.
            contentHandler(bestAttemptContent)
            return
        }

        Task {
            // A failed download still delivers the notification, just without art.
            if let attachment = await Self.downloadAttachment(from: attachmentURL) {
                bestAttemptContent.attachments = [attachment]
            }
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // `static` so the download doesn't capture `self`, and returning the
    // attachment instead of taking a completion handler keeps the whole path
    // clear of non-Sendable closure captures.
    private static func downloadAttachment(from url: URL) async -> UNNotificationAttachment? {
        do {
            let (downloadedURL, response) = try await URLSession.shared.download(from: url)

            // The system validates the file against its extension and rejects
            // the whole attachment if they disagree, so take the extension from
            // what the server actually sent rather than assuming PNG. A
            // Firebase Storage URL ends in `?alt=media&token=…`, so its path is
            // no help either.
            let fileExtension = Self.fileExtension(for: response)
            let destination = URL.temporaryDirectory
                .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
                .appendingPathExtension(fileExtension)

            try FileManager.default.moveItem(at: downloadedURL, to: destination)
            return try UNNotificationAttachment(identifier: "image", url: destination, options: nil)
        } catch {
            // Worth a line in Console: a rejected attachment is the difference
            // between artwork on the notification and a bare banner, and it
            // fails silently otherwise.
            Self.log.error("couldn't attach the activity artwork: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The filename extension matching what the server said it sent, defaulting
    /// to PNG — every activity image in Storage is one.
    private static func fileExtension(for response: URLResponse) -> String {
        guard let mimeType = response.mimeType,
              let type = UTType(mimeType: mimeType),
              let preferred = type.preferredFilenameExtension else {
            return "png"
        }
        return preferred
    }
}
