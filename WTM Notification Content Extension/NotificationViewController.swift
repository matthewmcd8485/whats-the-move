//
//  NotificationViewController.swift
//  WTM Notification Content Extension
//
//  Created by Matthew McDonnell on 7/2/21.
//

import UIKit
import UserNotifications
import UserNotificationsUI

/// The expanded ("long look") notification. The system already renders the
/// title and body above us — `UNNotificationExtensionDefaultContentHidden` is
/// off — so all this adds is the activity artwork, sized to its own aspect
/// ratio so there are no letterbox bars.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Clear, not the template's green — the system draws the notification
        // material behind us and any opaque colour fights with it.
        view.backgroundColor = .clear
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func didReceive(_ notification: UNNotification) {
        guard let attachment = notification.request.content.attachments.first(where: { $0.identifier == "image" }),
              let image = Self.loadImage(from: attachment) else {
            // Nothing to show — collapse to zero height rather than leaving a
            // blank block under the title.
            preferredContentSize = .zero
            return
        }

        imageView.image = image

        // Match the container's height to the artwork so it fills the width
        // exactly. The system clamps this to its own maximum.
        let aspectRatio = image.size.height / max(image.size.width, 1)
        preferredContentSize = CGSize(width: view.bounds.width, height: view.bounds.width * aspectRatio)
    }

    /// The attachment lives outside the extension's container, so the URL is
    /// security-scoped. Reading it without claiming access fails silently,
    /// which is why the artwork never appeared here.
    private static func loadImage(from attachment: UNNotificationAttachment) -> UIImage? {
        guard attachment.url.startAccessingSecurityScopedResource() else { return nil }
        defer { attachment.url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: attachment.url) else { return nil }
        return UIImage(data: data)
    }
}
