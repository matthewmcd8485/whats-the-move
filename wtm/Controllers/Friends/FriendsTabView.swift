//
//  FriendsTabView.swift
//  wtm?
//
//  The "friends" tab: my friends, incoming requests, adding by phone number,
//  importing from contacts, and the person detail screen.
//
//  Replaces RequestsViewController, AddFriendsViewController,
//  FriendVerifyViewController, ImportContactsViewController and
//  FriendViewController, plus the thin MyFriendsViewController host.
//

import SwiftUI
import PhoneNumberKit

// MARK: - Routes

enum FriendsRoute: Hashable {
    case requests
    case addFriends
    case importContacts
    /// Looking up someone by phone number before sending a request.
    case verify(phoneNumber: String)
    case detail(uid: String, name: String)
}

// MARK: - Root

struct FriendsTabView: View {
    @State private var path: [FriendsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MyFriendsView(
                onSelectFriend: { user in
                    path.append(.detail(uid: user.uid, name: user.name))
                },
                onTapRequests: { path.append(.requests) },
                onTapAddFriends: { path.append(.addFriends) }
            )
            .navigationDestination(for: FriendsRoute.self) { route in
                destination(for: route)
            }
        }
        .tint(.wtmDarkBlue)
    }

    @ViewBuilder
    private func destination(for route: FriendsRoute) -> some View {
        switch route {
        case .requests:
            RequestsView()
        case .addFriends:
            AddFriendsView(
                onSearch: { path.append(.verify(phoneNumber: $0)) },
                onImportContacts: { path.append(.importContacts) }
            )
        case .importContacts:
            ImportContactsView(onSelect: { path.append(.verify(phoneNumber: $0)) })
        case .verify(let phoneNumber):
            FriendVerifyView(phoneNumber: phoneNumber, onFinished: { path.removeAll() })
        case .detail(let uid, let name):
            FriendDetailView(uid: uid, name: name)
        }
    }
}

// MARK: - Requests

@Observable
@MainActor
final class RequestsModel {
    var requests: [FriendRequest] = []
    var isLoading = true

    func load() async {
        guard let uid = SecureStorage.uid else {
            isLoading = false
            return
        }
        defer { isLoading = false }
        do {
            let incoming = try await DatabaseManager.shared.downloadFriendRequests(uid: uid)
            requests = incoming
                .map { FriendRequest(name: $0.name.lowercased(), uid: $0.uid, profileImageURL: $0.profileImageURL) }
                .filter { !ReportingManager.shared.userIsBlocked(theirUID: $0.uid) }
        } catch {
            Log.database.error("error loading friend requests: \(error.localizedDescription, privacy: .public)")
        }
    }

    func accept(_ request: FriendRequest) async {
        guard let myUID = SecureStorage.uid,
              let myName = UserDefaults.standard.string(forKey: "name") else { return }
        do {
            try await DatabaseManager.shared.acceptFriendRequest(
                myUID: myUID,
                myName: myName,
                friendUID: request.uid,
                friendName: request.name
            )
            // Keep the cached friend list in step so the send flow sees the
            // new friend without waiting for a refresh.
            var cached = UserDefaults.standard.stringArray(forKey: "friendsUID") ?? []
            if !cached.contains(request.uid) {
                cached.append(request.uid)
                UserDefaults.standard.set(cached, forKey: "friendsUID")
            }
            requests.removeAll { $0.uid == request.uid }
        } catch {
            Log.database.error("error accepting friend request: \(error.localizedDescription, privacy: .public)")
        }
    }

    func decline(_ request: FriendRequest) {
        guard let myUID = SecureStorage.uid else { return }
        DatabaseManager.shared.deleteFriendRequest(forUID: myUID, fromUID: request.uid)
        // The old version cleared the whole list here, which wiped every other
        // pending request from the table.
        requests.removeAll { $0.uid == request.uid }
    }
}

struct RequestsView: View {
    @State private var model = RequestsModel()
    @State private var pending: FriendRequest?

    var body: some View {
        ScreenScaffold(title: "requests", scrolls: false) {
            content
        }
        .task { await model.load() }
        .confirmationDialog(
            "wow, you have friends!",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { request in
            Button("accept") {
                Task { await model.accept(request) }
            }
            Button("delete", role: .destructive) { model.decline(request) }
            Button("cancel", role: .cancel) {}
        } message: { request in
            Text("add \(request.name) as a friend?")
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            CenteredMessage(text: "loading...", color: .wtmDarkBlue)
        } else if model.requests.isEmpty {
            CenteredMessage(
                text: "no pending requests.\n\nlooks like no one wants to be your friend.\n\ntragic.",
                font: .wtmRegular(18, relativeTo: .body)
            )
        } else {
            List(model.requests, id: \.uid) { request in
                Button {
                    pending = request
                } label: {
                    HStack(spacing: 12) {
                        RemoteAvatarView(uid: request.uid, urlString: request.profileImageURL, size: 36)
                        Text(request.name)
                            .font(.wtmBold(20, relativeTo: .body))
                            .foregroundStyle(Color.wtmDarkBlue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.wtmBackground)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Add friends

struct AddFriendsView: View {
    var onSearch: (String) -> Void = { _ in }
    var onImportContacts: () -> Void = {}

    @State private var phoneNumber = ""
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        ScreenScaffold(
            title: "add friends",
            subtitle: "add friends by phone number using the search bar above."
        ) {
            VStack(spacing: 24) {
                PhoneNumberFieldView(text: $phoneNumber, onSubmit: search)
                    .frame(height: 40)
                    .onboardingField()
                    .accessibilityLabel("friend's phone number")

                PrimaryActionButton(title: "search", action: search)

                Text("or, because you're lazy, you can look through your contacts to find friends.")
                    .font(.wtmSubtitle)
                    .foregroundStyle(Color.wtmSecondaryLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                PrimaryActionButton(title: "import from contacts", action: onImportContacts)
            }
            .padding(.horizontal, WTMLayout.sideMargin)
            .padding(.top, 24)
        }
        .contentShape(.rect)
        .onTapGesture(perform: dismissKeyboard)
        .alert(errorTitle, isPresented: $showError) {
            Button("okay", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func search() {
        let entered = phoneNumber.trimmingCharacters(in: .whitespaces)

        guard !entered.isEmpty, entered != "+1" else {
            return fail("no phone number entered", "please enter a number before continuing.")
        }
        guard entered.hasPrefix("+") else {
            return fail("incorrect formatting", "please include the \"+\" at the beginning of the phone number.")
        }
        guard entered != SecureStorage.phoneNumber else {
            return fail("slow your roll", "you can't add yourself as a friend.\nmaybe try making real ones?")
        }
        onSearch(entered)
    }

    private func fail(_ title: String, _ message: String) {
        errorTitle = title
        errorMessage = message
        showError = true
    }
}

// MARK: - Verify a friend before adding

@Observable
@MainActor
final class FriendVerifyModel {
    var user: User?
    var isLoading = true
    /// Set when the flow can't continue; the view shows it then pops.
    var blockingMessage: (title: String, message: String)?

    func search(phoneNumber: String) async {
        defer { isLoading = false }
        do {
            let found = try await DatabaseManager.shared.downloadUser(
                where: FirestoreKeys.User.phoneNumber,
                isEqualTo: phoneNumber
            )
            guard !found.name.isEmpty else {
                blockingMessage = ("user not found", "there were no matches given the phone number provided.")
                return
            }
            if ReportingManager.shared.userIsBlocked(theirUID: found.uid)
                || ReportingManager.shared.userBlockedYou(theirUID: found.uid) {
                blockingMessage = (
                    "user is blocked",
                    "either they blocked you or you blocked them.\nwe don't know, though.\nit's not really our business.\n\nsorry for any drama this may cause..."
                )
                return
            }
            user = found
        } catch {
            blockingMessage = ("user not found", "there were no matches given the phone number provided.")
        }
    }

    /// Returns a message to show, or nil when the request went out.
    func sendRequest() async -> (title: String, message: String)? {
        guard let user,
              let uid = SecureStorage.uid,
              let name = UserDefaults.standard.string(forKey: "name"),
              let profileImageURL = UserDefaults.standard.string(forKey: "profileImageURL")
        else {
            return ("error adding friend", "don't worry.\nwe don't know what happened either.")
        }

        let existing = UserDefaults.standard.stringArray(forKey: "friendsUID") ?? []
        guard !existing.contains(user.uid) else {
            return ("already friends", "you can't send a friend request to someone you're already friends with.\n\nmaybe if you used the app how it was intended then you wouldn't be stuck here doing stupid stuff like trying to create duplicate friends.")
        }

        do {
            try await DatabaseManager.shared.sendFriendRequest(
                toUID: user.uid,
                fromName: name,
                fromUID: uid,
                profileImageURL: profileImageURL
            )
            return nil
        } catch {
            Log.database.error("error sending friend request: \(error.localizedDescription, privacy: .public)")
            return ("error adding friend", "we couldn't send the request. please try again.")
        }
    }
}

struct FriendVerifyView: View {
    let phoneNumber: String
    /// Called once a request has been sent, to unwind to the friends list.
    var onFinished: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var model = FriendVerifyModel()
    @State private var alert: (title: String, message: String)?
    @State private var showAlert = false

    var body: some View {
        PersonDetailLayout(
            title: "add friend",
            user: model.user,
            isLoading: model.isLoading,
            footer: {
                if model.user != nil {
                    VStack(spacing: 8) {
                        Text("add this friend?")
                            .font(.wtmRegular(18, relativeTo: .body))
                            .foregroundStyle(Color.wtmSecondaryLabel)
                        PrimaryActionButton(title: "add friend", action: addFriend)
                    }
                }
            }
        )
        .toolbar {
            if let user = model.user {
                ToolbarItem(placement: .topBarTrailing) {
                    ReportUserButton(uid: user.uid, name: user.name) { dismiss() }
                }
            }
        }
        .task { await model.search(phoneNumber: phoneNumber) }
        .onChange(of: model.blockingMessage?.title) { _, _ in
            if let blocking = model.blockingMessage {
                alert = blocking
                showAlert = true
            }
        }
        .alert(alert?.title ?? "", isPresented: $showAlert) {
            Button("okay") {
                // Every alert on this screen ends the flow one way or another.
                if model.blockingMessage != nil { dismiss() } else { onFinished() }
            }
        } message: {
            Text(alert?.message ?? "")
        }
    }

    private func addFriend() {
        Task {
            if let problem = await model.sendRequest() {
                alert = problem
                showAlert = true
            } else {
                onFinished()
            }
        }
    }
}

// MARK: - Friend detail

struct FriendDetailView: View {
    let uid: String
    let name: String

    @Environment(\.dismiss) private var dismiss
    @State private var user: User?
    @State private var isLoading = true
    @State private var alert: (title: String, message: String)?
    @State private var showAlert = false

    var body: some View {
        PersonDetailLayout(
            // Show who you're looking at rather than a generic heading; fall
            // back to the name we were handed until the fetch lands.
            title: (user?.name ?? name).lowercased(),
            user: user,
            isLoading: isLoading,
            footer: { EmptyView() }
        )
        .toolbar {
            if let user {
                ToolbarItem(placement: .topBarTrailing) {
                    ReportUserButton(uid: user.uid, name: user.name) { dismiss() }
                }
            }
        }
        .task { await load() }
        .alert(alert?.title ?? "", isPresented: $showAlert) {
            Button("rude, but okay") { dismiss() }
        } message: {
            Text(alert?.message ?? "")
        }
    }

    private func load() async {
        defer { isLoading = false }

        if ReportingManager.shared.userIsBlocked(theirUID: uid)
            || ReportingManager.shared.userBlockedYou(theirUID: uid) {
            fail("user is blocked", "either they blocked you or you blocked them.\nwe don't know, though.\nit's not really our business.\n\nsorry for any drama this may cause...")
            return
        }

        do {
            let found = try await DatabaseManager.shared.downloadUser(
                where: FirestoreKeys.User.userIdentifier,
                isEqualTo: uid
            )
            guard !found.name.isEmpty else {
                fail("friend not found", "we appear to be stuck inside a white void where your friends don't exist.\n\nor maybe it's just real life?")
                return
            }
            user = found
        } catch {
            fail("friend not found", "we appear to be stuck inside a white void where your friends don't exist.\n\nor maybe it's just real life?")
        }
    }

    private func fail(_ title: String, _ message: String) {
        alert = (title, message)
        showAlert = true
    }
}

/// Shared body of the two person screens: avatar, name, phone number and
/// status card, with a caller-supplied footer.
private struct PersonDetailLayout<Footer: View>: View {
    let title: String
    let user: User?
    let isLoading: Bool
    @ViewBuilder let footer: Footer

    var body: some View {
        ScreenScaffold(title: title) {
            VStack(spacing: 16) {
                if isLoading {
                    CenteredMessage(text: "loading...", color: .wtmDarkBlue)
                } else if let user {
                    RemoteAvatarView(uid: user.uid, urlString: user.profileImageURL, size: 180)
                        .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text(user.name)
                            .font(.wtmBold(28, relativeTo: .title))
                            .foregroundStyle(Color.wtmDarkBlue)
                        Text(user.phoneNumber)
                            .font(.wtmRegular(18, relativeTo: .body))
                            .foregroundStyle(Color.wtmSecondaryLabel)

                        // Only on profiles fetched whole — the cached copies
                        // the friends list renders from don't carry it, and a
                        // bare "joined" with nothing after it reads as a bug.
                        if !user.joinedTime.isEmpty {
                            Text("joined \(user.joinedTime.lowercased())")
                                .font(.wtmThin(15, relativeTo: .subheadline))
                                .foregroundStyle(Color.wtmTertiaryLabel)
                        }
                    }
                    .multilineTextAlignment(.center)

                    StatusCard(status: Status(stored: user.status), substatus: user.substatus)

                    footer
                }
            }
            .padding(.horizontal, WTMLayout.sideMargin)
            .padding(.top, 16)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    FriendsTabView()
}
