//
//  FriendGroupsView.swift
//  wtm?
//

import SwiftUI

@MainActor
final class FriendGroupsViewModel: ObservableObject {
    @Published var groups: [FriendGroup] = []
    @Published var isLoading = true

    func load() async {
        let cached = LocalCacheManager.shared.cachedFriendGroups()
        groups = cached
        if !cached.isEmpty { isLoading = false }

        if let uid = SecureStorage.uid {
            await LocalCacheManager.shared.refreshFromNetwork(myUID: uid)
        }
        groups = LocalCacheManager.shared.cachedFriendGroups()
        isLoading = false
    }
}

struct FriendGroupsView: View {
    var onSelectGroup: (FriendGroup) -> Void = { _ in }
    var onCreateGroup: (String) -> Void = { _ in }

    @StateObject private var viewModel = FriendGroupsViewModel()
    @State private var showNameAlert = false
    @State private var showFewFriendsAlert = false
    @State private var showProfanityAlert = false
    @State private var newGroupName = ""

    var body: some View {
        ZStack(alignment: .top) {
            Color("backgroundColors").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("friend groups")
                    .font(.custom("SuperBasic-Bold", size: 48))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .padding(.horizontal, 16)
                    .padding(.top, 36)

                content

                Button {
                    promptNewGroup()
                } label: {
                    Text("new group")
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
        .alert("name group", isPresented: $showNameAlert) {
            TextField("ex. the dream team", text: $newGroupName)
                .textInputAutocapitalization(.never)
            Button("cancel", role: .cancel) { newGroupName = "" }
            Button("save") { submitNewGroup() }
        } message: {
            Text("enter a name for the new group.")
        }
        .alert("slow your roll", isPresented: $showFewFriendsAlert) {
            Button("okay", role: .cancel) {}
        } message: {
            Text("you need to have at least two friends to create a friend group. nice try, though.")
        }
        .alert("ok, potty mouth", isPresented: $showProfanityAlert) {
            Button("okay", role: .cancel) {}
        } message: {
            Text("there are some less-than-ideal words used in your group name. please make sure it is appropriate.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.groups.isEmpty {
            Spacer()
            HStack { Spacer(); Text("loading...").font(.custom("SuperBasic-Bold", size: 25)).foregroundStyle(Color("secondaryLabelColors")); Spacer() }
            Spacer()
        } else if viewModel.groups.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Text("you don't have any groups yet.")
                Text("create one below.")
            }
            .font(.custom("SuperBasic-Regular", size: 15))
            .foregroundStyle(Color("secondaryLabelColors"))
            .frame(maxWidth: .infinity)
            Spacer()
        } else {
            List {
                ForEach(viewModel.groups, id: \.groupID) { group in
                    Button {
                        onSelectGroup(group)
                    } label: {
                        groupRow(group: group)
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
    private func groupRow(group: FriendGroup) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(group.name.lowercased())
                    .font(.custom("SuperBasic-Bold", size: 24))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .lineLimit(1)
                Text(peopleCountText(group: group))
                    .font(.custom("SuperBasic-Thin", size: 12))
                    .foregroundStyle(Color("secondaryLabelColors"))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
        }
        .contentShape(Rectangle())
    }

    private func peopleCountText(group: FriendGroup) -> String {
        let count = group.people?.count ?? 0
        return count == 1 ? "1 person" : "\(count) people"
    }

    private func promptNewGroup() {
        let friendsCount = UserDefaults.standard.integer(forKey: "friendsCount")
        let cachedFriendsCount = LocalCacheManager.shared.cachedFriendsCount()
        if max(friendsCount, cachedFriendsCount) < 2 {
            showFewFriendsAlert = true
            return
        }
        newGroupName = ""
        showNameAlert = true
    }

    private func submitNewGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        if ProfanityManager.shared.checkForProfanity(in: trimmed) {
            showProfanityAlert = true
            return
        }
        onCreateGroup(trimmed)
    }
}
