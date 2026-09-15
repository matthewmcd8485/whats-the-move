//
//  FriendSelectionView.swift
//  wtm?
//

import SwiftUI

enum RecipientTab: Hashable {
    case groups
    case friends
}

@MainActor
final class FriendSelectionViewModel: ObservableObject {
    @Published var groups: [SelectableGroup] = []
    @Published var friends: [Friend] = []
    @Published var isLoading = true

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
    var onBack: () -> Void = {}
    var onSelect: ([SelectableGroup], [Friend], Bool) -> Void = { _, _, _ in }

    @StateObject private var viewModel = FriendSelectionViewModel()
    @State private var activeTab: RecipientTab = .groups
    @State private var selectedGroupIDs: Set<String> = []
    @State private var selectedFriendUIDs: Set<String> = []
    @State private var showSendAllConfirm = false
    @State private var timeSensitive = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("backgroundColors").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("i'm bored")
                    .font(.custom("SuperBasic-Bold", size: 48))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Text("who would you like to annoy?")
                    .font(.custom("SuperBasic-Regular", size: 15))
                    .foregroundStyle(Color("secondaryLabelColors"))
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
                    HStack {
                        Spacer()
                        Text("loading...")
                            .font(.custom("SuperBasic-Bold", size: 25))
                            .foregroundStyle(Color("secondaryLabelColors"))
                        Spacer()
                    }
                    Spacer()
                } else {
                    listSection
                    bottomControls
                }
            }
            .padding(.top, 30)

            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .frame(width: 40, height: 40)
            }
            .padding(.leading, 16)
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.load()
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
                        .listRowBackground(Color("backgroundColors"))
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(.compact)
                .scrollContentBackground(.hidden)
                .background(Color("backgroundColors"))
            }
        case .friends:
            if viewModel.friends.isEmpty {
                emptyState(message: "you don't have any friends yet")
            } else {
                List {
                    ForEach(viewModel.friends, id: \.uid) { friend in
                        selectionRow(
                            label: friend.name,
                            subtitle: nil,
                            isSelected: selectedFriendUIDs.contains(friend.uid),
                            toggle: { toggleFriend(friend.uid) }
                        )
                        .listRowBackground(Color("backgroundColors"))
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(.compact)
                .scrollContentBackground(.hidden)
                .background(Color("backgroundColors"))
            }
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading) {
                Text("this is important")
                    .font(.custom("SuperBasic-Bold", size: 18))
                    .foregroundStyle(Color("darkBlueOnLight"))
                
                Text("send this notification as time sensitive")
                    .font(.custom("SuperBasic-Thin", size: 12))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            Toggle("", isOn: $timeSensitive)
                .labelsHidden()
                .tint(Color("darkBlueOnLight"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color("groupedCardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)

        Button {
            sendSelection()
        } label: {
            Text(sendButtonLabel)
                .font(.custom("SuperBasic-Bold", size: 20))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .frame(height: 53)
                .background(hasSelection ? Color("darkBlueOnLight") : Color("darkBlueOnLight").opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!hasSelection)
        .padding(.horizontal, 53)
        .padding(.bottom, 8)

        Button {
            showSendAllConfirm = true
        } label: {
            Text(sendAllButtonLabel)
                .font(.custom("SuperBasic-Regular", size: 16))
                .foregroundStyle(Color("darkBlueOnLight"))
                .contentTransition(.numericText())
                .animation(.snappy, value: activeTab)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
        }
        .disabled(!hasItemsForActiveTab)
        .padding(.horizontal, 53)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        Spacer()
        HStack {
            Spacer()
            Text(message)
                .font(.custom("SuperBasic-Regular", size: 18))
                .foregroundStyle(Color("secondaryLabelColors"))
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
                        .foregroundStyle(Color("darkBlueOnLight"))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.custom("SuperBasic-Regular", size: 13))
                            .foregroundStyle(Color("secondaryLabelColors"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isSelected ? Color("darkBlueOnLight") : Color("secondaryLabelColors"))
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
        let sorted = others.sorted { $0.name < $1.name }
        if sorted.count <= 3 {
            return sorted.map(\.name).joined(separator: ", ")
        }
        let head = sorted.prefix(3).map(\.name).joined(separator: ", ")
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

private final class FriendSelectionHostingController: UIHostingController<FriendSelectionView>, UIGestureRecognizerDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension FriendSelectionView {
    static func makeHostingController(mood: NotificationTitle) -> UIViewController {
        let hc = FriendSelectionHostingController(rootView: FriendSelectionView(mood: mood))
        hc.rootView = FriendSelectionView(
            mood: mood,
            onBack: { [weak hc] in
                hc?.navigationController?.popViewController(animated: true)
            },
            onSelect: { [weak hc] groups, friends, timeSensitive in
                let next = SwooshView.makeHostingController(mood: mood, groups: groups, individuals: friends, timeSensitive: timeSensitive)
                hc?.navigationController?.pushViewController(next, animated: true)
            }
        )
        return hc
    }
}
