//
//  MyFriendsView.swift
//  wtm?
//

import SwiftUI

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
            UserDefaults.standard.set(LocalCacheManager.shared.cachedFriendsCount(), forKey: "friendsCount")
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
}

struct MyFriendsView: View {
    var onSelectFriend: (User) -> Void = { _ in }
    var onTapRequests: () -> Void = {}
    var onTapAddFriends: () -> Void = {}

    @State private var viewModel = MyFriendsViewModel()

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
            // Two separate concerns, so two separate glass groups: reviewing
            // incoming requests, and adding someone new. The fixed spacer is
            // what splits them into distinct capsules.
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
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.friends.isEmpty {
            Spacer()
            CenteredMessage(text: "loading...")
            Spacer()
        } else if viewModel.friends.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Text("you don't have any friends.")
                Text("that's embarrassing.")
            }
            .font(.wtmSubtitle)
            .foregroundStyle(Color.wtmSecondaryLabel)
            .frame(maxWidth: .infinity)
            Spacer()
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

    /// Friends bucketed A–Z. The cache already returns them name-sorted.
    private var sections: [IndexedSection<User>] {
        alphabeticalSections(viewModel.friends) { $0.name }
    }

}


#Preview("Friends list") {
    NavigationStack {
        MyFriendsView()
    }
}
