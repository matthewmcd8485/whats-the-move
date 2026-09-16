//
//  GroupsTabView.swift
//  wtm?
//
//  The "groups" tab: the group list, a group's detail/member list, and picking
//  a friend to add. Replaces GroupDetailViewController, AddPeopleViewController
//  and the thin FriendGroupsViewController host.
//

import SwiftUI

// MARK: - Routes

enum GroupsRoute: Hashable {
    case detail(groupID: String)
    case friendDetail(uid: String, name: String)
    /// Someone in a shared group who isn't a friend yet.
    case verify(phoneNumber: String)
}

// MARK: - Root

struct GroupsTabView: View {
    @State private var path: [GroupsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            FriendGroupsView(
                onSelectGroup: { path.append(.detail(groupID: $0.groupID)) },
                onCreateGroup: createGroup
            )
            .navigationDestination(for: GroupsRoute.self) { route in
                destination(for: route)
            }
        }
        .tint(.wtmDarkBlue)
    }

    @ViewBuilder
    private func destination(for route: GroupsRoute) -> some View {
        switch route {
        case .detail(let groupID):
            GroupDetailView(
                groupID: groupID,
                onOpenFriend: { path.append(.friendDetail(uid: $0.uid, name: $0.name)) },
                onOpenStranger: { path.append(.verify(phoneNumber: $0.phoneNumber)) }
            )
        case .friendDetail(let uid, let name):
            FriendDetailView(uid: uid, name: name)
        case .verify(let phoneNumber):
            FriendVerifyView(phoneNumber: phoneNumber, onFinished: { path.removeLast() })
        }
    }

    private func createGroup(named name: String) {
        guard let uid = SecureStorage.uid else { return }
        Task {
            do {
                let groupID = try await DatabaseManager.shared.createGroup(name: name, ownerUID: uid)
                path.append(.detail(groupID: groupID))
            } catch {
                Log.database.error("error creating group: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - Group detail

@Observable
@MainActor
final class GroupDetailModel {
    var group: FriendGroup?
    var members: [User] = []
    var isLoading = true
    var failed = false
    var errorMessage: String?

    func load(groupID: String) async {
        defer { isLoading = false }
        do {
            let group = try await DatabaseManager.shared.loadGroup(groupID: groupID)
            self.group = group

            let uids = group.people ?? []
            guard !uids.isEmpty else { return }

            // One query per member, run concurrently rather than the old
            // serial loop that reloaded the table after every response.
            let fetched = await withTaskGroup(of: User?.self) { tasks in
                for uid in uids {
                    tasks.addTask {
                        try? await DatabaseManager.shared.downloadUser(
                            where: FirestoreKeys.User.userIdentifier,
                            isEqualTo: uid
                        )
                    }
                }
                var collected: [User] = []
                for await user in tasks {
                    if let user { collected.append(user) }
                }
                return collected
            }

            members = fetched
                .filterDuplicates { $0.uid == $1.uid }
                .sorted { $0.name.sortsBefore($1.name) }

            if members.isEmpty { failed = true }
        } catch {
            Log.database.error("error loading group: \(error.localizedDescription, privacy: .public)")
            failed = true
        }
    }

    func rename(to name: String) async {
        guard let group else { return }
        do {
            try await DatabaseManager.shared.renameGroup(groupID: group.groupID, name: name)
            self.group = FriendGroup(
                name: name,
                groupID: group.groupID,
                people: group.people,
                isDirect: group.isDirectGroup
            )
        } catch {
            errorMessage = "something went wrong when we tried to save your new group name. please try again."
        }
    }

    /// Takes someone out of the group. The row is dropped locally on success so
    /// the list doesn't have to make a round trip to catch up.
    func remove(_ member: User) async {
        guard let group else { return }
        do {
            try await DatabaseManager.shared.removePersonFromGroup(groupID: group.groupID, uid: member.uid)
            members.removeAll { $0.uid == member.uid }
            self.group = FriendGroup(
                name: group.name,
                groupID: group.groupID,
                people: (group.people ?? []).filter { $0 != member.uid },
                isDirect: group.isDirectGroup
            )
        } catch {
            Log.database.error("error removing person from group: \(error.localizedDescription, privacy: .public)")
            errorMessage = "we couldn't remove them from this group. please try again."
        }
    }

    /// Returns false when the person is already in the group.
    func leave() async -> Bool {
        guard let group, let uid = SecureStorage.uid else { return false }
        do {
            try await DatabaseManager.shared.removePersonFromGroup(groupID: group.groupID, uid: uid)
            var cached = UserDefaults.standard.stringArray(forKey: "groupsUID") ?? []
            cached.removeAll { $0 == group.groupID }
            UserDefaults.standard.set(cached, forKey: "groupsUID")
            return true
        } catch {
            Log.database.error("error leaving group: \(error.localizedDescription, privacy: .public)")
            errorMessage = "we couldn't remove you from this group. please try again."
            return false
        }
    }

    var peopleSummary: String {
        members.count == 1
            ? "you're the only one in this group!"
            : "\(members.count) people in this group"
    }
}

struct GroupDetailView: View {
    let groupID: String
    var onOpenFriend: (User) -> Void = { _ in }
    var onOpenStranger: (User) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var model = GroupDetailModel()
    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var showLeaveConfirm = false
    @State private var showProfanity = false
    @State private var notice: (title: String, message: String)?
    @State private var showNotice = false
    @State private var memberPendingRemoval: User?
    @State private var showAddPeople = false

    var body: some View {
        ScreenScaffold(title: model.group?.name.lowercased() ?? "group", scrolls: false) {
            content
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("add people", systemImage: "person.badge.plus") { showAddPeople = true }
                    Button("change name", systemImage: "pencil") {
                        draftName = ""
                        isRenaming = true
                    }
                    Button("leave group", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        showLeaveConfirm = true
                    }
                    // The destructive role reddens the title, but the glyph
                    // keeps inheriting the stack's `.tint(.wtmDarkBlue)` —
                    // tint is always respected, so it has to be overridden
                    // here for the icon to match the label.
                    .tint(.red)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .plainToolbarSymbol()
                .accessibilityLabel("group options")
            }
        }
        .task { await model.load(groupID: groupID) }
        .sheet(isPresented: $showAddPeople) {
            AddPeopleView(
                groupID: groupID,
                existingUIDs: Set(model.group?.people ?? []),
                onAdded: { Task { await model.load(groupID: groupID) } }
            )
        }
        .confirmationDialog("remove from group", item: $memberPendingRemoval, titleVisibility: .visible) { member in
            Button("remove \(member.uid == SecureStorage.uid ? "you" : member.name.lowercased())", role: .destructive) {
                Task { await model.remove(member) }
            }
            Button("cancel", role: .cancel) {}
        } message: { member in
            Text("\(member.uid == SecureStorage.uid ? "you" : member.name.lowercased()) will no longer get bored requests sent to this group.")
        }
        // `errorMessage` was being set by `rename` and never shown anywhere.
        .alert("something went wrong", item: Bindable(model).errorMessage) { _ in
            Button("okay", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert("change group name", isPresented: $isRenaming) {
            TextField("ex. the dream team", text: $draftName)
                .textInputAutocapitalization(.never)
            Button("cancel", role: .cancel) {}
            Button("save") { rename() }
        } message: {
            Text("enter a new name for the group.")
        }
        .confirmationDialog("leave group", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("leave", role: .destructive) {
                Task { if await model.leave() { dismiss() } }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("are you sure you want to leave this group?")
        }
        .alert("ok, potty mouth", isPresented: $showProfanity) {
            Button("okay", role: .cancel) {}
        } message: {
            Text("there are some less-than-ideal words used in your group name. please make sure it is appropriate.")
        }
        .alert(notice?.title ?? "", isPresented: $showNotice) {
            Button("okay", role: .cancel) {}
        } message: {
            Text(notice?.message ?? "")
        }
        .alert("group members not found", isPresented: Bindable(model).failed) {
            Button("rude, but okay") { dismiss() }
        } message: {
            Text("we appear to be stuck inside a white void where your group members don't exist.\n\nor maybe you just don't have any friends?")
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            CenteredMessage(text: "loading...", color: .wtmDarkBlue)
        } else {
            Text(model.peopleSummary)
                .font(.wtmThin(15, relativeTo: .subheadline))
                .foregroundStyle(Color.wtmSecondaryLabel)
                .padding(.horizontal, WTMLayout.sideMargin)
                .padding(.top, 4)

            List(model.members, id: \.uid) { member in
                Button {
                    open(member)
                } label: {
                    CompactPersonRow(user: member)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.wtmBackground)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing) {
                    // Your own row is left alone — "leave group" in the overflow
                    // menu is the same action with the right name on it.
                    if member.uid != SecureStorage.uid {
                        Button("remove", systemImage: "person.badge.minus", role: .destructive) {
                            memberPendingRemoval = member
                        }
                        // The destructive role alone leaves the swipe button
                        // on the navigation stack's blue tint, which reads as
                        // an ordinary action rather than a removal.
                        .tint(Color.wtmDarkRed)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
        }
    }

    private func rename() {
        let trimmed = draftName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !ProfanityManager.shared.checkForProfanity(in: trimmed) else {
            showProfanity = true
            return
        }
        Task { await model.rename(to: trimmed) }
    }

    private func open(_ member: User) {
        guard member.name != "user deleted" else {
            return notify("user deleted", "sorry, we don't specialize in communicating with ghosts.")
        }
        guard member.uid != SecureStorage.uid else {
            return notify("chill out, dude", "you can't stalk yourself, weirdo.")
        }
        if ReportingManager.shared.userIsBlocked(theirUID: member.uid)
            || ReportingManager.shared.userBlockedYou(theirUID: member.uid) {
            return notify("user blocked", "either you blocked this person, or they blocked you.\n\nquit it with these toxic friends!")
        }

        let friends = UserDefaults.standard.stringArray(forKey: "friendsUID") ?? []
        if friends.contains(member.uid) {
            onOpenFriend(member)
        } else {
            onOpenStranger(member)
        }
    }

    private func notify(_ title: String, _ message: String) {
        notice = (title, message)
        showNotice = true
    }
}

// MARK: - Add people

/// Presented as a sheet so picking several people is one self-contained task
/// that either commits or is thrown away. It used to be a pushed screen where
/// each tap added one person and popped, so adding three people meant three
/// round trips through the navigation stack — and picking someone already in
/// the group got you told off instead of simply not being offered.
struct AddPeopleView: View {
    let groupID: String
    /// Already in the group, so they're listed as present rather than pickable.
    var existingUIDs: Set<String> = []
    var onAdded: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [User] = []
    @State private var selected: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: "add people", subtitle: subtitle, scrolls: false) {
                content
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .plainToolbarSymbol()
                    .accessibilityLabel("cancel")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if selected.isEmpty || isSaving {
                        Button {} label: {
                            Image(systemName: "checkmark")
                        }
                        .plainToolbarSymbol()
                        .disabled(true)
                        .accessibilityLabel("add")
                    } else {
                        // Filled blue once there's something to commit, matching
                        // the send button on the bored flow.
                        Button(action: save) {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.wtmDarkBlue)
                        .accessibilityLabel("add \(selected.count) \(selected.count == 1 ? "person" : "people")")
                    }
                }
            }
            .task { await load() }
            .alert("error adding people", item: $errorMessage) { _ in
                Button("okay", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
        .tint(.wtmDarkBlue)
    }

    private var subtitle: String {
        selected.isEmpty
            ? "pick the friends you'd like to add to this group."
            : "\(selected.count) selected."
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            CenteredMessage(text: "loading...", color: .wtmDarkBlue)
        } else if friends.isEmpty {
            CenteredMessage(
                text: "you don't have any friends to add.\n\nmaybe go make some first?",
                font: .wtmRegular(15, relativeTo: .subheadline)
            )
        } else {
            List(friends, id: \.uid) { friend in
                let isPresent = existingUIDs.contains(friend.uid)

                Button {
                    toggle(friend.uid)
                } label: {
                    HStack(spacing: 8) {
                        CompactPersonRow(
                            user: friend,
                            accessory: isPresent ? .none : .checkbox(isOn: selected.contains(friend.uid))
                        )
                        if isPresent {
                            Text("already in")
                                .font(.wtmThin(12, relativeTo: .caption))
                                .foregroundStyle(Color.wtmTertiaryLabel)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPresent)
                .opacity(isPresent ? 0.45 : 1)
                .listRowBackground(Color.wtmBackground)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
        }
    }

    private func load() async {
        defer { isLoading = false }
        // Read from the local cache rather than firing one Firestore query per
        // friend the way the old controller did.
        friends = LocalCacheManager.shared.cachedFriendUsers(excluding: nil)
            .filter {
                !ReportingManager.shared.userIsBlocked(theirUID: $0.uid)
                    && !ReportingManager.shared.userBlockedYou(theirUID: $0.uid)
            }
    }

    private func toggle(_ uid: String) {
        withAnimation(.snappy) {
            if selected.contains(uid) {
                selected.remove(uid)
            } else {
                selected.insert(uid)
            }
        }
    }

    private func save() {
        guard !selected.isEmpty else { return }
        isSaving = true
        Task {
            do {
                try await DatabaseManager.shared.addPeopleToGroup(groupID: groupID, uids: Array(selected))
                onAdded()
                dismiss()
            } catch {
                Log.database.error("error adding people to group: \(error.localizedDescription, privacy: .public)")
                errorMessage = "we couldn't add them to the group. please try again."
                isSaving = false
            }
        }
    }
}

#Preview {
    GroupsTabView()
}
