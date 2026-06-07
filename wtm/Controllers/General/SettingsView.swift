//
//  SettingsView.swift
//  wtm?
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    var onBack: () -> Void = {}
    var onAbout: () -> Void = {}
    var onDeleteAccount: () -> Void = {}
    var onLoggedOut: () -> Void = {}

    @State private var explicit = UserDefaults.standard.bool(forKey: "explicit")
    @State private var showLogOutConfirm = false
    @State private var showLogOutFailed = false
    @State private var showDeleteConfirm = false
    @State private var showExplicitSaveError = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("backgroundColors").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        explicitSection.padding(.top, 16)
                        infoSection.padding(.top, 22)
                        logOutSection.padding(.top, 22)
                        deleteSection
                            .padding(.top, 22)
                            .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 16)
                }
            }

            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .frame(width: 40, height: 40)
            }
            .padding(.leading, 16)
        }
        .navigationBarHidden(true)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings")
                .font(.custom("SuperBasic-Bold", size: 48))
                .foregroundStyle(Color("darkBlueOnLight"))

            Text("make your changes to the space-time continuum here.")
                .font(.custom("SuperBasic-Regular", size: 15))
                .foregroundStyle(Color("secondaryLabelColors"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 61)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("backgroundColors"))
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
            linkRow(icon: "trash.fill", title: "delete account", color: Color("darkRedOnLight")) {
                showDeleteConfirm = true
            }
        }
    }

    private var explicitToggleRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color("darkBlueOnLight"))
                .frame(width: 24)
            Text("explicit mode")
                .font(.custom("SuperBasic-Bold", size: 18))
                .foregroundStyle(Color("darkBlueOnLight"))
            Spacer()
            Toggle("", isOn: $explicit)
                .labelsHidden()
                .tint(Color("darkBlueOnLight"))
                .onChange(of: explicit) { _, newValue in
                    saveExplicit(newValue)
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    private func linkRow(icon: String, title: String, color: Color = Color("darkBlueOnLight"), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.custom("SuperBasic-Bold", size: 18))
                    .foregroundStyle(color)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(CardRowButtonStyle())
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color("secondaryLabelColors").opacity(0.18))
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("groupedCardBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.custom("SuperBasic-Regular", size: 13))
            .foregroundStyle(Color("secondaryLabelColors"))
            .padding(.horizontal, 16)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func saveExplicit(_ newValue: Bool) {
        UserDefaults.standard.set(newValue, forKey: "explicit")

        guard let uid = SecureStorage.uid else { return }
        DatabaseManager.shared.updateUserExplicit(uid: uid, enabled: newValue) { result in
            if case .failure = result {
                DispatchQueue.main.async {
                    let reverted = !newValue
                    explicit = reverted
                    UserDefaults.standard.set(reverted, forKey: "explicit")
                    showExplicitSaveError = true
                }
            }
        }
    }

    private func performLogOut() {
        do {
            try Auth.auth().signOut()
            onLoggedOut()
        } catch {
            print("Sign out process failed: \(error)")
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

private final class SettingsHostingController: UIHostingController<SettingsView>, UIGestureRecognizerDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension SettingsView {
    static func makeHostingController() -> UIViewController {
        let hc = SettingsHostingController(rootView: SettingsView())
        hc.rootView = SettingsView(
            onBack: { [weak hc] in
                hc?.navigationController?.popViewController(animated: true)
            },
            onAbout: { [weak hc] in
                hc?.navigationController?.pushViewController(AboutThisAppView.makeHostingController(), animated: true)
            },
            onDeleteAccount: { [weak hc] in
                hc?.navigationController?.pushViewController(DeleteAccountView.makeHostingController(), animated: true)
            },
            onLoggedOut: { [weak hc] in
                guard let hc else { return }
                hc.navigationController?.viewControllers = [hc]
                hc.tabBarController?.viewControllers = [hc]
                UserDefaults.resetDefaults()
                UserDefaults.standard.set(true, forKey: "launchedBefore")
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(identifier: "loadingViewController") as LoadingViewController
                hc.navigationController?.pushViewController(vc, animated: true)
            }
        )
        return hc
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
