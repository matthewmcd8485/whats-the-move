//
//  FriendGroupsView.swift
//  wtm?
//

import SwiftUI

@Observable
@MainActor
final class FriendGroupsViewModel {
    var groups: [FriendGroup] = []
    var isLoading = true

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

    @State private var viewModel = FriendGroupsViewModel()
    @State private var showNameAlert = false
    @State private var showFewFriendsAlert = false
    @State private var showProfanityAlert = false
    @State private var newGroupName = ""

    var body: some View {
        ZStack(alignment: .top) {
            Color.wtmBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("groups")
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
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: promptNewGroup) {
                    Image(systemName: "plus")
                }
                .plainToolbarSymbol()
                .accessibilityLabel("new group")
            }
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
            CenteredMessage(text: "loading...")
        } else if viewModel.groups.isEmpty {
            CenteredMessage(
                text: "you don't have any groups yet.\n\ncreate one below.",
                font: .wtmSubtitle
            )
        } else {
            List {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items, id: \.groupID) { group in
                            Button {
                                onSelectGroup(group)
                            } label: {
                                groupRow(group: group)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.wtmBackground)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                            // Matches the friends list: single-line rows in an
                            // A–Z sectioned list don't need hairlines as well.
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        SectionLetterHeader(letter: section.id)
                    }
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

    private var sections: [IndexedSection<FriendGroup>] {
        alphabeticalSections(viewModel.groups) { $0.name }
    }

    @ViewBuilder
    private func groupRow(group: FriendGroup) -> some View {
        HStack(spacing: 10) {
            Text(group.name.lowercased())
                .font(.wtmBold(18, relativeTo: .body))
                .foregroundStyle(Color.wtmDarkBlue)
                .lineLimit(1)

            Spacer(minLength: 8)

            // Groups have no status glyph, so the member count stays — but it
            // sits inline rather than on a second line, keeping the row to one.
            Text(peopleCountText(group: group))
                .font(.wtmThin(13, relativeTo: .footnote))
                .foregroundStyle(Color.wtmSecondaryLabel)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 38)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private func peopleCountText(group: FriendGroup) -> String {
        let count = group.people?.count ?? 0
        return count == 1 ? "1 person" : "\(count) people"
    }

    private func promptNewGroup() {
        if LocalCacheManager.shared.cachedFriendsCount() < 2 {
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
