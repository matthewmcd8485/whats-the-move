//
//  NotificationViewController.swift
//  WTM Notification Content Extension
//
//  Created by Matthew McDonnell on 7/2/21.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import os

/// The expanded ("long look") notification. The system already renders the
/// title and body above us — `UNNotificationExtensionDefaultContentHidden` is
/// off — so all this adds is the activity artwork.
///
/// Note that this *replaces* the system's own attachment view: once a content
/// extension is registered for the category, iOS stops drawing the attached
/// image itself. So anything this fails to load shows up as an empty panel
/// sized by `UNNotificationExtensionInitialContentSizeRatio`, which is what was
/// appearing on long press. Two things caused that, and both are handled here:
///
/// - `preferredContentSize` was computed in `didReceive`, before the host had
///   laid the view out, so it was derived from a `bounds.width` of zero.
/// - The attachment was the only source of the image. When the service
///   extension can't produce one — an unrecognised file type, a download that
///   ran out of time — there was nothing to fall back on.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private static let log = Logger(subsystem: "com.matthew.wtm-", category: "push")

    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Height over width of whatever is on screen. `nil` until we know, so a
    /// first layout pass doesn't resize the panel to nothing before the image
    /// has arrived.
    private var artworkAspectRatio: CGFloat?

    private var downloadTask: Task<Void, Never>?

    deinit {
        downloadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Clear, not the template's green — the system draws the notification
        // material behind us and any opaque colour fights with it.
        view.backgroundColor = .clear
        view.addSubview(imageView)
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The host owns our width and only tells us what it is by laying us
        // out, so this is the earliest point a height can be asked for.
        updatePreferredContentSize()
    }

    func didReceive(_ notification: UNNotification) {
        if let image = Self.attachedImage(in: notification) {
            show(image)
            return
        }

        guard let urlString = notification.request.content.userInfo["url"] as? String,
              let url = URL(string: urlString) else {
            Self.log.error("notification had neither a readable attachment nor an artwork URL")
            showNothing()
            return
        }

        // Fetching here is a last resort — Apple's guidance is to render from
        // what's already on the notification — but an empty panel is worse than
        // a brief spinner, and by this point the attachment has already failed.
        Self.log.info("attachment unavailable; fetching the artwork directly")
        spinner.startAnimating()
        downloadTask = Task { [weak self] in
            let image = await Self.downloadImage(from: url)
            guard let self, !Task.isCancelled else { return }
            if let image {
                show(image)
            } else {
                showNothing()
            }
        }
    }

    // MARK: - Presenting

    private func show(_ image: UIImage) {
        spinner.stopAnimating()
        imageView.image = image
        artworkAspectRatio = image.size.width > 0 ? image.size.height / image.size.width : 0.75
        updatePreferredContentSize()
    }

    /// Collapses the panel rather than leaving a blank block under the title.
    private func showNothing() {
        spinner.stopAnimating()
        imageView.image = nil
        artworkAspectRatio = 0
        updatePreferredContentSize()
    }

    /// Matches the panel's height to the artwork so it fills the width exactly
    /// with no letterbox bars. The system clamps this to its own maximum.
    private func updatePreferredContentSize() {
        guard let artworkAspectRatio else { return }

        let width = view.bounds.width > 0 ? view.bounds.width : preferredContentSize.width
        guard width > 0 else { return }

        let height = (width * artworkAspectRatio).rounded()
        // Setting this triggers another layout pass, so only react to a real
        // change or the two bounce off each other indefinitely.
        guard abs(height - preferredContentSize.height) > 0.5 else { return }
        preferredContentSize = CGSize(width: width, height: height)
    }

    // MARK: - Loading

    /// Reads the image off the notification's attachments.
    ///
    /// The attachment lives in the system's data store, outside this
    /// extension's container, so its URL is security-scoped and reading it
    /// without claiming access fails silently. Not every delivery needs the
    /// claim, though, so a failed claim is worth reading through rather than
    /// bailing on — and the identifier isn't filtered any more either, since a
    /// non-matching one is no reason to show nothing.
    private static func attachedImage(in notification: UNNotification) -> UIImage? {
        for attachment in notification.request.content.attachments {
            let url = attachment.url
            let claimed = url.startAccessingSecurityScopedResource()
            defer { if claimed { url.stopAccessingSecurityScopedResource() } }

            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return image
            }
            log.error("couldn't read attachment \(attachment.identifier, privacy: .public) (access claimed: \(claimed))")
        }
        return nil
    }

    private static func downloadImage(from url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        // The long look is already on screen by now; a slow fetch has to give
        // up rather than hold an empty panel open.
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            log.error("artwork fetch failed")
            return nil
        }
        return UIImage(data: data)
    }
}
