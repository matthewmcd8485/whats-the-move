//
//  FriendSelectionView.swift
//  wtm?
//

import SwiftUI

enum RecipientTab: Hashable {
    case groups
    case friends
}

@Observable
@MainActor
final class FriendSelectionViewModel {
    var groups: [SelectableGroup] = []
    var friends: [Friend] = []
    var isLoading = true

    func load() async {
        guard let uid = SecureStorage.uid else {
            isLoading = false
            return
        }

        // 1. Cache-first read — renders immediately if anything is cached.
        let cachedGroups = LocalCacheManager.shared.cachedSelectableGroups()
        let cachedFriends = filteredFriends(LocalCacheManager.shared.cachedFriends(excluding: uid))
        groups = cachedGroups
        friends = cachedFriends
        if !cachedGroups.isEmpty || !cachedFriends.isEmpty {
            isLoading = false
        }

        // 2. Refresh from network, then re-publish from the now-fresh cache.
        await LocalCacheManager.shared.refreshFromNetwork(myUID: uid)
        groups = LocalCacheManager.shared.cachedSelectableGroups()
        friends = filteredFriends(LocalCacheManager.shared.cachedFriends(excluding: uid))
        isLoading = false
    }

    private func filteredFriends(_ source: [Friend]) -> [Friend] {
        source.filter { friend in
            !ReportingManager.shared.userIsBlocked(theirUID: friend.uid)
                && !ReportingManager.shared.userBlockedYou(theirUID: friend.uid)
        }
    }
}

struct FriendSelectionView: View {
    let mood: NotificationTitle
    var onSelect: ([SelectableGroup], [Friend], Bool) -> Void = { _, _, _ in }

    @State private var viewModel = FriendSelectionViewModel()
    @State private var activeTab: RecipientTab = .groups
    @State private var selectedGroupIDs: Set<String> = []
    @State private var selectedFriendUIDs: Set<String> = []
    @State private var showSendAllConfirm = false
    @State private var timeSensitive = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.wtmBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("i'm bored")
                    .font(.wtmLargeTitle)
                    .foregroundStyle(Color.wtmDarkBlue)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Text("who would you like to annoy?")
                    .font(.wtmSubtitle)
                    .foregroundStyle(Color.wtmSecondaryLabel)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Picker("recipient type", selection: $activeTab) {
                    Text("groups").tag(RecipientTab.groups)
                    Text("friends").tag(RecipientTab.friends)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if viewModel.isLoading {
                    Spacer()
                    CenteredMessage(text: "loading...")
                    Spacer()
                } else {
                    listSection
                    timeSensitiveRow
                }
            }
            .padding(.top, 8)

        }
        .task {
            await viewModel.load()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(sendAllButtonLabel, systemImage: "megaphone") {
                        showSendAllConfirm = true
                    }
                    .disabled(!hasItemsForActiveTab)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .plainToolbarSymbol()
                .accessibilityLabel("more sending options")
            }

            // Send is the screen's primary action, so it gets its own glass
            // group rather than sharing a capsule with the overflow menu.
            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                if hasSelection {
                    // Prominent glass reads as a filled blue button, so "ready
                    // to send" is obvious at a glance rather than being carried
                    // by the glyph's colour alone.
                    Button(action: sendSelection) {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.wtmDarkBlue)
                    .accessibilityLabel(sendButtonLabel)
                } else {
                    Button(action: sendSelection) {
                        Image(systemName: "paperplane.fill")
                    }
                    .plainToolbarSymbol()
                    .disabled(true)
                    .accessibilityLabel("send")
                }
            }
        }
        .alert("are you sure?", isPresented: $showSendAllConfirm) {
            Button("nevermind, cancel", role: .cancel) {}
            Button("let's do this") {
                UserDefaults.standard.setValue(Date(), forKey: "sendToAllDate")
                switch activeTab {
                case .groups:
                    onSelect(viewModel.groups, [], timeSensitive)
                case .friends:
                    onSelect([], viewModel.friends, timeSensitive)
                }
            }
        } message: {
            Text("don't be annoying if you don't have to.\n\ndoing this will disable your sending privileges for two hours.")
        }
    }

    @ViewBuilder
    private var listSection: some View {
        switch activeTab {
        case .groups:
            if viewModel.groups.isEmpty {
                emptyState(message: "you don't have any groups yet")
            } else {
                List {
                    ForEach(viewModel.groups, id: \.group.groupID) { selectable in
                        selectionRow(
                            label: selectable.group.name,
                            subtitle: memberSubtitle(for: selectable),
                            isSelected: selectedGroupIDs.contains(selectable.group.groupID),
                            toggle: { toggleGroup(selectable.group.groupID) }
                        )
                        .listRowBackground(Color.wtmBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(.compact)
                .scrollContentBackground(.hidden)
                .background(Color.wtmBackground)
            }
        case .friends:
            if viewModel.friends.isEmpty {
                emptyState(message: "you don't have any friends yet")
            } else {
                List {
                    ForEach(viewModel.friends, id: \.uid) { friend in
                        selectionRow(
                            // Lowercased for display like every other person
                            // row in the app; older accounts still hold
                            // capitals, which read as the odd one out here.
                            label: friend.name.lowercased(),
                            subtitle: nil,
                            isSelected: selectedFriendUIDs.contains(friend.uid),
                            toggle: { toggleFriend(friend.uid) }
                        )
                        .listRowBackground(Color.wtmBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(.compact)
                .scrollContentBackground(.hidden)
                .background(Color.wtmBackground)
            }
        }
    }

    @ViewBuilder
    private var timeSensitiveRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text("this is important")
                    .font(.wtmBold(18, relativeTo: .body))
                    .foregroundStyle(Color.wtmDarkBlue)

                Text("send this notification as time sensitive")
                    .font(.wtmThin(12, relativeTo: .caption))
                    .foregroundStyle(.primary)
            }

            Spacer()
            Toggle("time sensitive", isOn: $timeSensitive)
                .labelsHidden()
                .tint(.wtmDarkBlue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.wtmGroupedCard)
        .clipShape(RoundedRectangle(cornerRadius: WTMLayout.cardCornerRadius))
        .padding(.horizontal, WTMLayout.sideMargin)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        Spacer()
        HStack {
            Spacer()
            Text(message)
                .font(.custom("SuperBasic-Regular", size: 18))
                .foregroundStyle(Color.wtmSecondaryLabel)
            Spacer()
        }
        Spacer()
    }

    @ViewBuilder
    private func selectionRow(label: String, subtitle: String?, isSelected: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.custom("SuperBasic-Bold", size: 20))
                        .foregroundStyle(Color.wtmDarkBlue)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.custom("SuperBasic-Regular", size: 13))
                            .foregroundStyle(Color.wtmSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isSelected ? Color.wtmDarkBlue : Color.wtmSecondaryLabel)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func memberSubtitle(for selectable: SelectableGroup) -> String {
        let myUID = SecureStorage.uid
        let others = selectable.friends.filter { $0.uid != myUID }
        guard !others.isEmpty else { return "" }
        let sorted = others.sorted { $0.name.sortsBefore($1.name) }
        if sorted.count <= 3 {
            return sorted.map { $0.name.lowercased() }.joined(separator: ", ")
        }
        let head = sorted.prefix(3).map { $0.name.lowercased() }.joined(separator: ", ")
        let remaining = sorted.count - 3
        return "\(head) and \(remaining) more"
    }

    private var hasSelection: Bool {
        !selectedGroupIDs.isEmpty || !selectedFriendUIDs.isEmpty
    }

    private var hasItemsForActiveTab: Bool {
        switch activeTab {
        case .groups: return !viewModel.groups.isEmpty
        case .friends: return !viewModel.friends.isEmpty
        }
    }

    private var sendButtonLabel: String {
        let count = selectedGroupIDs.count + selectedFriendUIDs.count
        return count > 0 ? "send (\(count))" : "send"
    }

    private var sendAllButtonLabel: String {
        switch activeTab {
        case .groups: return "send to all groups"
        case .friends: return "send to all friends"
        }
    }

    private func toggleGroup(_ id: String) {
        withAnimation(.snappy) {
            if selectedGroupIDs.contains(id) {
                selectedGroupIDs.remove(id)
            } else {
                selectedGroupIDs.insert(id)
            }
        }
    }

    private func toggleFriend(_ uid: String) {
        withAnimation(.snappy) {
            if selectedFriendUIDs.contains(uid) {
                selectedFriendUIDs.remove(uid)
            } else {
                selectedFriendUIDs.insert(uid)
            }
        }
    }

    private func sendSelection() {
        let chosenGroups = viewModel.groups.filter { selectedGroupIDs.contains($0.group.groupID) }
        let chosenFriends = viewModel.friends.filter { selectedFriendUIDs.contains($0.uid) }
        guard !chosenGroups.isEmpty || !chosenFriends.isEmpty else { return }
        onSelect(chosenGroups, chosenFriends, timeSensitive)
    }
}

