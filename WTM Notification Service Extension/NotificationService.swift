//
//  NotificationService.swift
//  WTM Notification Service Extension
//
//  Created by Matthew McDonnell on 7/2/21.
//

import UserNotifications
import Foundation

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
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
            let (downloadedURL, _) = try await URLSession.shared.download(from: url)
            let destination = URL.temporaryDirectory
                .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString + ".png")
            try FileManager.default.moveItem(at: downloadedURL, to: destination)
            return try UNNotificationAttachment(identifier: "image", url: destination, options: nil)
        } catch {
            return nil
        }
    }
}
