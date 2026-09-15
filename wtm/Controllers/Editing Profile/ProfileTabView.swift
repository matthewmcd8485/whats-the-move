//
//  ProfileTabView.swift
//  wtm?
//
//  The "myself" tab as a single SwiftUI NavigationStack.
//
//  Before this, the tab was a bar-hidden UINavigationController rooted at
//  MyProfileViewController, and every screen in it drew its own back chevron
//  because there was no navigation bar to put one in. Each screen also had to
//  ship a UIHostingController subclass just to re-enable the interactive pop
//  gesture the hidden bar had taken away.
//
//  Now there's one real navigation bar. The back button and the settings gear
//  are ordinary toolbar items, which means the system draws them — and on iOS
//  26 and later that means Liquid Glass, scroll-edge effects and the standard
//  back-swipe, all without the app asking for any of it.
//

import SwiftUI

// MARK: - Routes

enum ProfileRoute: Hashable {
    case settings
    case about
    case deleteAccount
    case editStatus
    case substatus(Status)
    case editPicture
}

// MARK: - Root

struct ProfileTabView: View {
    @Environment(SessionModel.self) private var session
    @State private var path: [ProfileRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MyProfileView(
                onOpenSettings: { path.append(.settings) },
                onEditStatus: { path.append(.editStatus) },
                onEditPicture: { path.append(.editPicture) }
            )
            .navigationDestination(for: ProfileRoute.self) { route in
                destination(for: route)
            }
        }
        .tint(.wtmDarkBlue)
    }

    @ViewBuilder
    private func destination(for route: ProfileRoute) -> some View {
        switch route {
        case .settings:
            SettingsView(
                onAbout: { path.append(.about) },
                onDeleteAccount: { path.append(.deleteAccount) },
                onSignedOut: session.signOut
            )
        case .about:
            AboutThisAppView()
        case .deleteAccount:
            DeleteAccountView(onDeleted: session.signOut)
        case .editStatus:
            // The status itself isn't persisted until a substatus is chosen and
            // the write succeeds — otherwise backing out of the substatus list
            // left the local status out of step with Firestore.
            EditStatusView(onSelect: { path.append(.substatus($0)) })
        case .substatus(let status):
            // Saving a substatus completes the whole edit, so unwind to the
            // profile rather than stepping back one screen at a time.
            SubstatusView(status: status, onFinished: { path.removeAll() })
        case .editPicture:
            PictureEditView(onSaved: { path.removeLast() })
        }
    }
}

#Preview {
    ProfileTabView()
        .environment(SessionModel())
}
