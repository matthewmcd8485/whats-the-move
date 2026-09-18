//
//  MyFriendsView.swift
//  wtm?
//

import SwiftUI

/// What the friends list is narrowed to.
///
/// A status isn't stored for a friend whose profile hasn't been fetched yet, so
/// filtering on one hides them until it lands — which is the honest answer to
/// "who's available", and why `everyone` stays the default.
enum FriendStatusFilter: String, CaseIterable, Identifiable {
    case all
    case available
    case busy
    case doNotDisturb

    var id: String { rawValue }

    /// The status this keeps, or `nil` for no filtering at all.
    var status: Status? {
        switch self {
        case .all: nil
        case .available: .available
        case .busy: .busy
        case .doNotDisturb: .doNotDisturb
        }
    }

    var label: String {
        switch self {
        case .all: "everyone"
        case .available: "available"
        case .busy: "busy"
        case .doNotDisturb: "stfu!"
        }
    }

    var iconName: String {
        status?.iconName ?? "person.2"
    }

    /// What to say when nothing matches.
    var emptyMessage: String {
        switch self {
        case .all: "you don't have any friends.\n\nthat's embarrassing."
        case .available: "none of your friends are available right now."
        case .busy: "all of your friends have better things to do."
        case .doNotDisturb: "nobody is telling you to go away right now.\n\nenjoy it."
        }
    }
}

@Observable
@MainActor
final class MyFriendsViewModel {
    var friends: [User] = []
    var isLoading = true

    func load() async {
        let myUID = SecureStorage.uid

        // 1. Cache-first render.
        let cached = filteredFriends(LocalCacheManager.shared.cachedFriendUsers(excluding: myUID))
        friends = cached
        if !cached.isEmpty { isLoading = false }

        // 2. Refresh from network. First pulls the friends list so we have UIDs,
        // then hydrates each user's profile (status, image URL, etc.) into the
        // cache. Re-publishes from cache when done.
        if let uid = myUID {
            await LocalCacheManager.shared.refreshFromNetwork(myUID: uid)
            await LocalCacheManager.shared.refreshFriendStatuses(myUID: uid)
        }
        friends = filteredFriends(LocalCacheManager.shared.cachedFriendUsers(excluding: myUID))
        isLoading = false
    }

    private func filteredFriends(_ source: [User]) -> [User] {
        source.filter { user in
            !ReportingManager.shared.userIsBlocked(theirUID: user.uid)
                && !ReportingManager.shared.userBlockedYou(theirUID: user.uid)
        }
    }

    /// Unfriends someone from both sides, then takes them out of everything
    /// local that still names them. Returns false if the write failed.
    func remove(_ user: User) async -> Bool {
        guard let myUID = SecureStorage.uid else { return false }

        do {
            try await DatabaseManager.shared.removeFriend(myUID: myUID, friendUID: user.uid)
        } catch {
            Log.database.error("error removing friend: \(error.localizedDescription, privacy: .public)")
            return false
        }

        friends.removeAll { $0.uid == user.uid }

        // Re-reading from the server is what prunes them out of the local
        // cache; the server no longer lists them, so the refresh drops them —
        // which is also what stops the send flow offering them as a recipient.
        await LocalCacheManager.shared.refreshFromNetwork(myUID: myUID)
        friends = filteredFriends(LocalCacheManager.shared.cachedFriendUsers(excluding: myUID))

        return true
    }
}

struct MyFriendsView: View {
    var onSelectFriend: (User) -> Void = { _ in }
    var onTapRequests: () -> Void = {}
    var onTapAddFriends: () -> Void = {}

    @State private var viewModel = MyFriendsViewModel()
    @State private var statusFilter: FriendStatusFilter = .all
    @State private var friendPendingRemoval: User?
    @State private var showRemovalFailure = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.wtmBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("my friends")
                    .font(.wtmLargeTitle)
                    .foregroundStyle(Color.wtmDarkBlue)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, WTMLayout.sideMargin)
                    .padding(.top, 8)

                content
            }
        }
        .task {
            await viewModel.load()
        }
        .toolbar {
            // Three separate concerns, so three separate glass groups:
            // narrowing what's on screen, reviewing incoming requests, and
            // adding someone new. The fixed spacers split them into distinct
            // capsules. Filtering comes first — it scopes the list rather than
            // taking you somewhere else.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("show", selection: $statusFilter) {
                        ForEach(FriendStatusFilter.allCases) { option in
                            Label(option.label, systemImage: option.iconName)
                                .tag(option)
                        }
                    }
                } label: {
                    // Filled while a filter is on, so it's clear the list is
                    // showing a subset rather than everyone you know.
                    Image(systemName: statusFilter == .all
                          ? "line.3.horizontal.decrease"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .plainToolbarSymbol()
                .accessibilityLabel("filter by status")
            }

            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onTapRequests) {
                    Image(systemName: "paperplane")
                }
                .plainToolbarSymbol()
                .accessibilityLabel("friend requests")
            }

            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onTapAddFriends) {
                    Image(systemName: "plus")
                }
                .plainToolbarSymbol()
                .accessibilityLabel("add friends")
            }
        }
        .confirmationDialog(
            "remove friend",
            isPresented: Binding(
                get: { friendPendingRemoval != nil },
                set: { if !$0 { friendPendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: friendPendingRemoval
        ) { friend in
            Button("remove", role: .destructive) { remove(friend) }
            Button("oops, cancel", role: .cancel) {}
        } message: { friend in
            Text("remove \(friend.name.lowercased()) as a friend?\n\nany groups you're both in will NOT be deleted.\n\nyou'll have to add each other again.")
        }
        .alert("couldn't remove friend", isPresented: $showRemovalFailure) {
            Button("okay", role: .cancel) {}
        } message: {
            Text("something went wrong. please try again.")
        }
    }

    private func remove(_ friend: User) {
        Task {
            let removed = await viewModel.remove(friend)
            if !removed { showRemovalFailure = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.friends.isEmpty {
            CenteredMessage(text: "loading...")
        } else if visibleFriends.isEmpty {
            CenteredMessage(text: statusFilter.emptyMessage, font: .wtmSubtitle)
        } else {
            List {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items, id: \.uid) { user in
                            Button {
                                onSelectFriend(user)
                            } label: {
                                CompactPersonRow(user: user)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.wtmBackground)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                            // The rows are a single line with their own
                            // spacing; hairlines between them just added
                            // noise to a list that's already sectioned A–Z.
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button("remove", systemImage: "person.badge.minus", role: .destructive) {
                                    friendPendingRemoval = user
                                }
                                .tint(Color.wtmDarkRed)
                            }
                        }
                    } header: {
                        SectionLetterHeader(letter: section.id)
                    }
                    // Drives the Contacts-style A–Z scrubber.
                    .sectionIndexLabel(section.id)
                }
            }
            .listStyle(.plain)
            .listSectionIndexVisibility(.visible)
            .scrollContentBackground(.hidden)
            .background(Color.wtmBackground)
            .refreshable {
                await viewModel.load()
            }
        }
    }

    /// The friends the current filter lets through.
    private var visibleFriends: [User] {
        guard let status = statusFilter.status else { return viewModel.friends }
        return viewModel.friends.filter { Status(loaded: $0.status) == status }
    }

    /// Friends bucketed A–Z. The cache already returns them name-sorted.
    private var sections: [IndexedSection<User>] {
        alphabeticalSections(visibleFriends) { $0.name }
    }

}


#Preview("Friends list") {
    NavigationStack {
        MyFriendsView()
    }
}
