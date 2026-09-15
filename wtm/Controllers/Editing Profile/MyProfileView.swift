//
//  MyProfileView.swift
//  wtm?
//
//  Rebuilt from the `myProfileViewController` storyboard scene: a heading, a
//  profile card, a status card, and three "customize" tiles.
//
//  The scene positioned all 22 subviews with absolute frames on a 390x844
//  canvas and rounded the cards by poking `layer.cornerRadius` in
//  `viewDidLoad`. This lays the same design out with stacks so it survives
//  other screen sizes and larger text, and the settings gear has moved into a
//  real navigation-bar item.
//

import SwiftUI

// MARK: - Model

@Observable
@MainActor
final class MyProfileModel {
    var name = ""
    var joined = ""
    var status: Status = .available
    var substatus = ""
    var profileImage: UIImage?

    /// Set when saving a new name fails, so the view can show an alert.
    var saveError: String?

    /// Reads the values the rest of the app keeps in UserDefaults. Called on
    /// every appearance because the edit screens write there and pop back.
    func reload() {
        let defaults = UserDefaults.standard
        name = defaults.string(forKey: "name") ?? "johnny appleseed"
        joined = defaults.string(forKey: "joinedTime") ?? Date().month
        substatus = defaults.string(forKey: "substatus") ?? "ready to mingle"

        let raw = defaults.string(forKey: "status") ?? Status.available.rawValue
        // Anything unrecognised is treated as do-not-disturb, matching the old
        // `configureStatusUI` which fell through to the red "nosign" state.
        status = Status(rawValue: raw) ?? .doNotDisturb
    }

    /// Loads the cached avatar off the main thread. `Data` crosses isolation
    /// safely where `UIImage` would not, so the file is read in the background
    /// and decoded here.
    func loadProfileImage() async {
        guard let url = ImageStoreManager.shared.filePath(forKey: "profileImage") else { return }
        let data = await Task.detached { try? Data(contentsOf: url) }.value
        guard let data else { return }
        profileImage = UIImage(data: data)
    }

    /// Validates and saves a new display name. Throws a user-facing message.
    func save(name newName: String) async throws {
        let trimmed = newName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= 16 else {
            throw ProfileError("name is too long", "read the directions, dude.\nwe aren't trying to write a shakespeare play here.")
        }
        guard !ProfanityManager.shared.checkForProfanity(in: trimmed) else {
            throw ProfileError("ok, potty mouth", "there are some less-than-ideal words used in your name. please make sure it is appropriate.")
        }
        guard let uid = SecureStorage.uid else {
            throw ProfileError("error updating name", "there was an error loading your profile details. please try again.")
        }

        do {
            try await DatabaseManager.shared.updateUserName(uid: uid, name: trimmed)
        } catch {
            Log.database.error("Failed to save name: \(error.localizedDescription, privacy: .public)")
            throw ProfileError("error saving name", "something went wrong when we tried to save your new name. please try again.")
        }

        UserDefaults.standard.set(trimmed, forKey: "name")
        name = trimmed
    }
}

struct ProfileError: LocalizedError {
    let title: String
    let message: String

    init(_ title: String, _ message: String) {
        self.title = title
        self.message = message
    }

    var errorDescription: String? { message }
}

// MARK: - View

struct MyProfileView: View {
    var onOpenSettings: () -> Void = {}
    var onEditStatus: () -> Void = {}
    var onEditPicture: () -> Void = {}

    @State private var model = MyProfileModel()
    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var errorTitle = ""
    @State private var showError = false

    private static let cardCorner: CGFloat = 25

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("my profile")
                    .font(.wtmLargeTitle)
                    .foregroundStyle(Color.wtmDarkBlue)
                    .accessibilityAddTraits(.isHeader)

                profileCard
                statusCard

                Text("-- customize your profile --")
                    .font(.wtmThin(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.wtmSecondaryLabel)
                    .frame(maxWidth: .infinity)

                customizeTiles
            }
            .padding(.horizontal, WTMLayout.sideMargin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.wtmBackground)
        .scrollBounceBehavior(.basedOnSize)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gear")
                }
                .plainToolbarSymbol()
                .accessibilityLabel("settings")
            }
        }
        .onAppear { model.reload() }
        .task { await model.loadProfileImage() }
        .alert("change your name", isPresented: $isEditingName) {
            TextField("ex. joe schmoe", text: $draftName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("cancel", role: .cancel) {}
            Button("save") { saveName() }
        } message: {
            Text("16 characters max.\nremember to keep it PG, please.")
        }
        .alert(errorTitle, isPresented: $showError) {
            Button("okay", role: .cancel) {}
        } message: {
            Text(model.saveError ?? "")
        }
    }

    // MARK: Cards

    private var profileCard: some View {
        HStack(spacing: 16) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name.lowercased())
                    .font(.wtmBold(22, relativeTo: .title3))
                    // Names cap at 16 characters, which just fits on one line;
                    // shrink slightly before wrapping so the card stays tidy.
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text("joined \(model.joined.lowercased())")
                    .font(.wtmThin(15, relativeTo: .subheadline))
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wtmDarkBlue)
        .clipShape(RoundedRectangle(cornerRadius: Self.cardCorner))
    }

    private var avatar: some View {
        Group {
            if let image = model.profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.wtmLightBlue)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        // The storyboard put a tap recogniser straight on the image view.
        .onTapGesture(perform: onEditPicture)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("edit profile picture")
    }

    private var statusCard: some View {
        Button(action: onEditStatus) {
            HStack(spacing: 16) {
                Image(systemName: model.status.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(Color.wtmLightBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("current status:")
                        .font(.wtmBold(20, relativeTo: .title3))
                        .foregroundStyle(Color.wtmLightBlue)
                    Text(model.status.rawValue)
                        .font(.wtmBold(27, relativeTo: .title2))
                        .foregroundStyle(statusColor)
                    Text("\"\(model.substatus.lowercased())\"")
                        .font(.wtmThin(15, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.wtmDarkBlue)
            .clipShape(RoundedRectangle(cornerRadius: Self.cardCorner))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("current status \(model.status.rawValue), \(model.substatus). edit status")
    }

    /// Matches the original, which tinted this label with the system colours
    /// rather than the app palette.
    private var statusColor: Color {
        switch model.status {
        case .available: .green
        case .busy: .yellow
        case .doNotDisturb: .red
        }
    }

    // MARK: Tiles

    private var customizeTiles: some View {
        HStack(alignment: .top, spacing: 12) {
            tile(icon: "quote.bubble", title: "edit status", action: onEditStatus)
            tile(icon: "camera.viewfinder", title: "edit picture", action: onEditPicture)
            tile(icon: "keyboard.badge.ellipsis", title: "edit name") {
                draftName = ""
                isEditingName = true
            }
        }
    }

    private func tile(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(Color.wtmLightBlue)
                    .frame(height: 50)
                Text(title)
                    .font(.wtmBold(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.wtmTertiaryLabel)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func saveName() {
        let entered = draftName
        Task {
            do {
                try await model.save(name: entered)
            } catch let error as ProfileError {
                errorTitle = error.title
                model.saveError = error.message
                showError = true
            } catch {
                errorTitle = "error saving name"
                model.saveError = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        MyProfileView()
    }
}
