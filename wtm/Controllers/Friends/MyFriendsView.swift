//
//  MyFriendsView.swift
//  wtm?
//

import SwiftUI

@MainActor
final class MyFriendsViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var isLoading = true

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

    @StateObject private var viewModel = MyFriendsViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            Color("backgroundColors").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("my friends")
                        .font(.custom("SuperBasic-Bold", size: 48))
                        .foregroundStyle(Color("darkBlueOnLight"))
                    Spacer()
                    Button(action: onTapRequests) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(Color("darkBlueOnLight"))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 36)

                content

                Button(action: onTapAddFriends) {
                    Text("add friends")
                        .font(.custom("SuperBasic-Bold", size: 20))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 53)
                        .background(Color("darkBlueOnLight"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 53)
                .padding(.bottom, 24)
            }
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.friends.isEmpty {
            Spacer()
            HStack { Spacer(); Text("loading...").font(.custom("SuperBasic-Bold", size: 25)).foregroundStyle(Color("secondaryLabelColors")); Spacer() }
            Spacer()
        } else if viewModel.friends.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Text("you don't have any friends.")
                Text("that's embarrassing.")
            }
            .font(.custom("SuperBasic-Regular", size: 15))
            .foregroundStyle(Color("secondaryLabelColors"))
            .frame(maxWidth: .infinity)
            Spacer()
        } else {
            List {
                ForEach(viewModel.friends, id: \.uid) { user in
                    Button {
                        onSelectFriend(user)
                    } label: {
                        friendRow(user: user)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color("backgroundColors"))
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .background(Color("backgroundColors"))
            .refreshable {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func friendRow(user: User) -> some View {
        HStack(spacing: 12) {
            statusIcon(for: user)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName(for: user))
                    .font(.custom("SuperBasic-Bold", size: 22))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .lineLimit(1)
                Text(statusLine(for: user))
                    .font(.custom("SuperBasic-Thin", size: 12))
                    .foregroundStyle(Color("secondaryLabelColors"))
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusIcon(for user: User) -> some View {
        let blockedYou = ReportingManager.shared.userIsBlocked(theirUID: user.uid)
        let blockedMe = ReportingManager.shared.userBlockedYou(theirUID: user.uid)

        Group {
            if user.name == "user deleted" {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(.gray)
            } else if blockedYou || blockedMe {
                Image(systemName: "hand.raised.slash")
                    .foregroundStyle(.red)
            } else if user.status == "available" {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.green)
            } else if user.status == "busy" {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(Color("darkYellowOnLight"))
            } else {
                Image(systemName: "nosign")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 22, weight: .regular))
    }

    private func displayName(for user: User) -> String {
        if user.uid == SecureStorage.uid { return "you" }
        return user.name.lowercased()
    }

    private func statusLine(for user: User) -> String {
        if user.name == "user deleted" { return "no status available" }
        let blockedYou = ReportingManager.shared.userIsBlocked(theirUID: user.uid)
        let blockedMe = ReportingManager.shared.userBlockedYou(theirUID: user.uid)
        if blockedYou || blockedMe { return "blocked" }
        return user.status
    }
}
