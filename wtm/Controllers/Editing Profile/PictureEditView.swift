//
//  PictureEditView.swift
//  wtm?
//
//  Replaces PictureEditViewController and PictureEditHandlers.
//
//  The old screen used `UIImagePickerController` with `allowsEditing` for the
//  crop step. `PhotosPicker` is the supported route now, and it doesn't need a
//  delegate, a representable, or the photo-library usage prompt that
//  UIImagePickerController triggered. The image is still squared off before
//  upload so it fills the circular frame the way the editing crop used to.
//

import SwiftUI
import PhotosUI

// MARK: - Model

@Observable
@MainActor
final class PictureEditModel {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    var image: UIImage?
    var state: SaveState = .idle

    /// Loads whatever is already cached on device.
    func loadExisting() async {
        guard let url = ImageStoreManager.shared.filePath(forKey: "profileImage") else { return }
        let data = await Task.detached { try? Data(contentsOf: url) }.value
        guard let data else { return }
        image = UIImage(data: data)
    }

    func apply(pickerItem: PhotosPickerItem?) async {
        guard let pickerItem else { return }
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let picked = UIImage(data: data) else {
            state = .failed("we couldn't read that photo. try another one?")
            return
        }
        image = picked.squaredForAvatar()
        state = .idle
    }

    func save() async {
        guard let image, let uid = SecureStorage.uid else { return }
        guard let data = image.pngData() else {
            state = .failed("we couldn't prepare that photo for upload.")
            return
        }

        state = .saving
        do {
            let url = try await StorageManager.shared.uploadProfilePicture(
                with: data,
                fileName: "\(uid) - profile image.png"
            )
            UserDefaults.standard.set(url, forKey: "profileImageURL")
            DatabaseManager.shared.updateUserProfileImageURL(uid: uid, url: url)
            ImageStoreManager.shared.store(image: image, forKey: "profileImage")
            state = .saved
        } catch {
            Log.storage.error("Error uploading profile picture: \(error.localizedDescription, privacy: .public)")
            state = .failed("there was an error saving your new image. please try again.")
        }
    }
}

// MARK: - View

struct PictureEditView: View {
    /// Called once the new image is stored, so the caller can pop.
    var onSaved: () -> Void = {}

    @State private var model = PictureEditModel()
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ScreenScaffold(
            title: "edit your\nprofile picture",
            subtitle: "give us your best.\n\nlet's be real, though, your best is probably still pretty bad."
        ) {
            VStack(spacing: 20) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    avatar
                }
                .buttonStyle(.plain)
                .accessibilityLabel("choose a photo")

                statusLine

                PrimaryActionButton(title: "save") {
                    Task { await model.save() }
                }
                .disabled(model.image == nil || model.state == .saving)
                .opacity(model.image == nil ? 0.4 : 1)
            }
            .padding(.horizontal, WTMLayout.sideMargin)
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
        }
        .task { await model.loadExisting() }
        .onChange(of: pickerItem) { _, newValue in
            Task { await model.apply(pickerItem: newValue) }
        }
        .onChange(of: model.state) { _, newValue in
            // Give the "image saved!" confirmation a beat before popping, the
            // way the old 0.5s delay did.
            guard newValue == .saved else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                onSaved()
            }
        }
    }

    private var avatar: some View {
        Group {
            if let image = model.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.wtmDarkBlue)
                    .padding(30)
            }
        }
        .frame(width: 220, height: 220)
        .clipShape(.circle)
        .overlay(Circle().stroke(Color.wtmDarkBlue.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private var statusLine: some View {
        switch model.state {
        case .idle:
            Text("tap the photo to pick a new one")
                .font(.wtmThin(13, relativeTo: .footnote))
                .foregroundStyle(Color.wtmSecondaryLabel)
        case .saving:
            HStack(spacing: 8) {
                ProgressView()
                Text("saving...")
                    .font(.wtmBold(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.wtmSecondaryLabel)
            }
        case .saved:
            Text("image saved!")
                .font(.wtmBold(15, relativeTo: .subheadline))
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .font(.wtmRegular(13, relativeTo: .footnote))
                .foregroundStyle(Color.wtmDarkRed)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Squaring

private extension UIImage {
    /// Centre-crops to a square so the picked photo fills the circular avatar
    /// rather than being letterboxed. `UIImagePickerController.allowsEditing`
    /// used to do this interactively.
    func squaredForAvatar() -> UIImage {
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let square = CGRect(origin: origin, size: CGSize(width: side, height: side))

        guard let cropped = cgImage?.cropping(to: square) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

#Preview {
    NavigationStack {
        PictureEditView()
    }
}
