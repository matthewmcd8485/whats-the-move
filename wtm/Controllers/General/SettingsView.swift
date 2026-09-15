//
//  SettingsView.swift
//  wtm?
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    var onAbout: () -> Void = {}
    var onDeleteAccount: () -> Void = {}
    /// Called after Firebase sign-out succeeds; the caller resets the app root.
    var onSignedOut: () -> Void = {}

    @State private var explicit = UserDefaults.standard.bool(forKey: "explicit")
    @State private var showLogOutConfirm = false
    @State private var showLogOutFailed = false
    @State private var showDeleteConfirm = false
    @State private var showExplicitSaveError = false
    @State private var showExplicitUnderConstruction = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                explicitSection.padding(.top, 16)
                infoSection.padding(.top, 22)
                logOutSection.padding(.top, 22)
                deleteSection
                    .padding(.top, 22)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, WTMLayout.sideMargin)
            .padding(.top, 8)
        }
        .background(Color.wtmBackground)
        .scrollBounceBehavior(.basedOnSize)
        .symbolRenderingMode(.hierarchical)
        .alert("log out", isPresented: $showLogOutConfirm) {
            Button("cancel", role: .cancel) {}
            Button("log out") { performLogOut() }
        } message: {
            Text("are you sure you want to log out?")
        }
        .alert("delete account", isPresented: $showDeleteConfirm) {
            Button("cancel", role: .cancel) {}
            Button("delete account") { onDeleteAccount() }
        } message: {
            Text("are you sure you want to delete your account?\n\nthis action cannot be undone.")
        }
        .alert("sign out failed", isPresented: $showLogOutFailed) {
            Button("ok", role: .cancel) {}
        } message: {
            Text("there was an error logging you out. please try again.")
        }
        .alert("couldn't save", isPresented: $showExplicitSaveError) {
            Button("ok", role: .cancel) {}
        } message: {
            Text("we couldn't update your explicit mode setting. please try again.")
        }
        .alert("still under construction", isPresented: $showExplicitUnderConstruction) {
            Button("fine, i'll wait", role: .cancel) {}
        } message: {
            Text("explicit mode isn't finished yet.\n\nwe'll remember that you want it, but nothing gets any saltier until it ships.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings")
                .font(.wtmLargeTitle)
                .foregroundStyle(Color.wtmDarkBlue)
                .accessibilityAddTraits(.isHeader)

            Text("make your changes to the space-time continuum here.")
                .font(.wtmSubtitle)
                .foregroundStyle(Color.wtmSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var explicitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            card {
                explicitToggleRow
            }
            sectionFooter("let us offend you more")
        }
    }

    private var infoSection: some View {
        card {
            VStack(spacing: 0) {
                linkRow(icon: "lock.shield", title: "privacy policy") {
                    open("https://matthewdevteam.weebly.com/privacy.html")
                }
                rowDivider
                linkRow(icon: "doc.text", title: "terms & conditions") {
                    open("https://matthewdevteam.weebly.com/terms-and-conditions.html")
                }
                rowDivider
                linkRow(icon: "gearshape", title: "view iOS settings") {
                    open(UIApplication.openSettingsURLString)
                }
                rowDivider
                linkRow(icon: "info.circle", title: "about", action: onAbout)
            }
        }
    }

    private var logOutSection: some View {
        card {
            linkRow(icon: "rectangle.portrait.and.arrow.right", title: "log out") {
                showLogOutConfirm = true
            }
        }
    }

    private var deleteSection: some View {
        card {
            linkRow(icon: "trash.fill", title: "delete account", color: .wtmDarkRed) {
                showDeleteConfirm = true
            }
        }
    }

    private var explicitToggleRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color.wtmDarkBlue)
                .frame(width: 24)
            Text("explicit mode")
                .font(.wtmBold(18, relativeTo: .body))
                .foregroundStyle(Color.wtmDarkBlue)
            Spacer()
            Toggle("explicit mode", isOn: $explicit)
                .labelsHidden()
                .tint(.wtmDarkBlue)
                .onChange(of: explicit) { _, newValue in
                    saveExplicit(newValue)
                }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }

    private func linkRow(
        icon: String,
        title: String,
        color: Color = .wtmDarkBlue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 24)
                Text(title)
                    .font(.wtmBold(18, relativeTo: .body))
                Spacer(minLength: 0)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(.rect)
        }
        .buttonStyle(CardRowButtonStyle())
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.wtmSecondaryLabel.opacity(0.18))
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.wtmGroupedCard)
            .clipShape(RoundedRectangle(cornerRadius: WTMLayout.cardCornerRadius))
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.wtmRegular(13, relativeTo: .footnote))
            .foregroundStyle(Color.wtmSecondaryLabel)
            .padding(.horizontal, 16)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func saveExplicit(_ newValue: Bool) {
        UserDefaults.standard.set(newValue, forKey: "explicit")

        // The preference is stored and synced, but nothing reads it yet — say
        // so when it's switched on rather than letting it look like a no-op.
        if newValue {
            showExplicitUnderConstruction = true
        }

        guard let uid = SecureStorage.uid else { return }
        Task {
            do {
                try await DatabaseManager.shared.updateUserExplicit(uid: uid, enabled: newValue)
            } catch {
                // Roll the toggle back so the UI matches what's stored.
                let reverted = !newValue
                explicit = reverted
                UserDefaults.standard.set(reverted, forKey: "explicit")
                showExplicitSaveError = true
            }
        }
    }

    private func performLogOut() {
        do {
            try Auth.auth().signOut()
            onSignedOut()
        } catch {
            Log.auth.error("Sign out failed: \(error.localizedDescription, privacy: .public)")
            showLogOutFailed = true
        }
    }
}

private struct CardRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.white.opacity(0.06) : Color.clear)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
