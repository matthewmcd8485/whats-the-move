//
//  LocalCacheManager.swift
//  wtm?
//
//  Local SwiftData cache for friends + groups so screens that read these
//  collections (e.g. FriendSelectionView, MyFriendsView, FriendGroupsView)
//  can render immediately while a background refresh updates them from
//  Firestore.
//

import Foundation
import SwiftData

@Model
final class CachedFriend {
    @Attribute(.unique) var uid: String
    var name: String
    var status: String = ""
    var substatus: String = ""
    var profileImageURL: String = ""
    var phoneNumber: String = ""
    var updatedAt: Date

    init(uid: String, name: String, status: String = "", substatus: String = "", profileImageURL: String = "", phoneNumber: String = "", updatedAt: Date = .now) {
        self.uid = uid
        self.name = name
        self.status = status
        self.substatus = substatus
        self.profileImageURL = profileImageURL
        self.phoneNumber = phoneNumber
        self.updatedAt = updatedAt
    }
}

@Model
final class CachedGroup {
    @Attribute(.unique) var groupID: String
    var name: String
    var isDirect: Bool
    var peopleUIDs: [String]
    // Parallel to peopleUIDs; some members may not be in the user's own friends
    // list (e.g. friends-of-friends in a shared group), so we denormalize names
    // here rather than join through CachedFriend.
    var memberNames: [String]
    var updatedAt: Date

    init(groupID: String, name: String, isDirect: Bool, peopleUIDs: [String], memberNames: [String], updatedAt: Date = .now) {
        self.groupID = groupID
        self.name = name
        self.isDirect = isDirect
        self.peopleUIDs = peopleUIDs
        self.memberNames = memberNames
        self.updatedAt = updatedAt
    }
}

@MainActor
final class LocalCacheManager {
    static let shared = LocalCacheManager()

    let container: ModelContainer

    private init() {
        let url = URL.applicationSupportDirectory.appendingPathComponent("wtmLocalCache.store")
        let config = ModelConfiguration(url: url)
        do {
            container = try ModelContainer(for: CachedFriend.self, CachedGroup.self, configurations: config)
        } catch {
            // Schema mismatch from a prior build — wipe and retry. The cache is
            // pure derived state so it's always safe to recreate.
            print("cache init failed (\(error)); recreating store")
            try? FileManager.default.removeItem(at: url)
            do {
                container = try ModelContainer(for: CachedFriend.self, CachedGroup.self, configurations: config)
            } catch {
                fatalError("failed to create SwiftData container after wipe: \(error)")
            }
        }
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Reads (synchronous, instant)
    //
    // These sort the mapped value types rather than passing a SortDescriptor to
    // FetchDescriptor. A KeyPath into a SwiftData @Model class isn't Sendable,
    // so `SortDescriptor(\.name)` trips strict concurrency checking; sorting the
    // Sendable DTOs afterwards is equivalent and avoids the crossing entirely.
    func cachedFriends(excluding myUID: String?) -> [Friend] {
        let results = (try? context.fetch(FetchDescriptor<CachedFriend>())) ?? []
        return results
            .filter { $0.uid != myUID && $0.name != "user deleted" }
            .map { Friend(name: $0.name, uid: $0.uid) }
            .sorted { $0.name.sortsBefore($1.name) }
    }

    func cachedFriendUsers(excluding myUID: String?) -> [User] {
        let results = (try? context.fetch(FetchDescriptor<CachedFriend>())) ?? []
        return results
            .filter { $0.uid != myUID && $0.name != "user deleted" }
            .map { cached in
                User(
                    name: cached.name,
                    phoneNumber: cached.phoneNumber,
                    uid: cached.uid,
                    fcmToken: "",
                    status: cached.status,
                    substatus: cached.substatus,
                    profileImageURL: cached.profileImageURL,
                    joinedTime: "",
                    explicit: false
                )
            }
            .sorted { $0.name.sortsBefore($1.name) }
    }

    func cachedSelectableGroups() -> [SelectableGroup] {
        let results = (try? context.fetch(FetchDescriptor<CachedGroup>())) ?? []
        return results
            .filter { !$0.isDirect }
            .map { cached in
                let members = zip(cached.peopleUIDs, cached.memberNames).map { Friend(name: $1, uid: $0) }
                let group = FriendGroup(name: cached.name, groupID: cached.groupID, people: cached.peopleUIDs, isDirect: cached.isDirect)
                return SelectableGroup(group: group, friends: members, isSelected: false)
            }
            .sorted { $0.group.name.sortsBefore($1.group.name) }
    }

    func cachedFriendGroups() -> [FriendGroup] {
        let results = (try? context.fetch(FetchDescriptor<CachedGroup>())) ?? []
        return results
            .filter { !$0.isDirect }
            .map { FriendGroup(name: $0.name, groupID: $0.groupID, people: $0.peopleUIDs, isDirect: $0.isDirect) }
            .sorted { $0.name.sortsBefore($1.name) }
    }

    func cachedFriendsCount() -> Int {
        let descriptor = FetchDescriptor<CachedFriend>()
        let results = (try? context.fetch(descriptor)) ?? []
        return results.filter { $0.name != "user deleted" }.count
    }

    // MARK: - Writes
    private func upsertFriend(uid: String, name: String) {
        let descriptor = FetchDescriptor<CachedFriend>(predicate: #Predicate { $0.uid == uid })
        if let existing = try? context.fetch(descriptor).first {
            existing.name = name
            existing.updatedAt = .now
        } else {
            context.insert(CachedFriend(uid: uid, name: name))
        }
    }

    private func upsertFullFriend(_ user: User) {
        let uid = user.uid
        let descriptor = FetchDescriptor<CachedFriend>(predicate: #Predicate { $0.uid == uid })
        if let existing = try? context.fetch(descriptor).first {
            existing.name = user.name
            existing.status = user.status
            existing.substatus = user.substatus
            existing.profileImageURL = user.profileImageURL
            existing.phoneNumber = user.phoneNumber
            existing.updatedAt = .now
        } else {
            context.insert(CachedFriend(
                uid: user.uid,
                name: user.name,
                status: user.status,
                substatus: user.substatus,
                profileImageURL: user.profileImageURL,
                phoneNumber: user.phoneNumber
            ))
        }
    }

    private func upsertGroup(groupID: String, name: String, isDirect: Bool, peopleUIDs: [String], memberNames: [String]) {
        let descriptor = FetchDescriptor<CachedGroup>(predicate: #Predicate { $0.groupID == groupID })
        if let existing = try? context.fetch(descriptor).first {
            existing.name = name
            existing.isDirect = isDirect
            existing.peopleUIDs = peopleUIDs
            existing.memberNames = memberNames
            existing.updatedAt = .now
        } else {
            context.insert(CachedGroup(
                groupID: groupID,
                name: name,
                isDirect: isDirect,
                peopleUIDs: peopleUIDs,
                memberNames: memberNames
            ))
        }
    }

    private func pruneFriends(keeping keep: Set<String>) {
        let descriptor = FetchDescriptor<CachedFriend>()
        for friend in (try? context.fetch(descriptor)) ?? [] where !keep.contains(friend.uid) {
            context.delete(friend)
        }
    }

    private func pruneGroups(keeping keep: Set<String>) {
        let descriptor = FetchDescriptor<CachedGroup>()
        for group in (try? context.fetch(descriptor)) ?? [] where !keep.contains(group.groupID) {
            context.delete(group)
        }
    }

    private func save() {
        do { try context.save() } catch {
            print("cache save failed: \(error)")
        }
    }

    // MARK: - Refresh
    // Pulls friends + groups (with members) from Firestore and upserts into the
    // local cache. Safe to call repeatedly; later screens read from cache for
    // instant rendering.
    func refreshFromNetwork(myUID: String) async {
        let db = DatabaseManager.shared

        async let friendsFetch: [Friend]? = {
            do { return try await db.downloadAllFriends(uid: myUID) }
            catch { print("cache refresh — friends: \(error)"); return nil }
        }()

        async let groupsFetch: [FriendGroup]? = {
            do { return try await db.downloadAllGroups(uid: myUID) }
            catch { print("cache refresh — groups: \(error)"); return nil }
        }()

        let (friendsOpt, groupsOpt) = await (friendsFetch, groupsFetch)

        if let friends = friendsOpt {
            let keep = Set(friends.map(\.uid))
            pruneFriends(keeping: keep)
            for friend in friends {
                upsertFriend(uid: friend.uid, name: friend.name)
            }
        }

        if let groups = groupsOpt {
            let keep = Set(groups.map(\.groupID))
            pruneGroups(keeping: keep)

            // For each non-direct group, also load member names so list rows
            // can show subtitles without an extra fetch.
            for group in groups {
                let people = group.people ?? []
                var memberNames = Array(repeating: "", count: people.count)
                if !group.isDirectGroup, !people.isEmpty {
                    if let members = try? await db.downloadFriends(fromGroupWith: people) {
                        let byUID = Dictionary(uniqueKeysWithValues: members.map { ($0.uid, $0.name) })
                        memberNames = people.map { byUID[$0] ?? "" }
                    }
                }
                upsertGroup(
                    groupID: group.groupID,
                    name: group.name,
                    isDirect: group.isDirectGroup,
                    peopleUIDs: people,
                    memberNames: memberNames
                )
            }
        }

        save()
    }

    // Fetches the full User document for each cached friend in parallel and
    // hydrates status / profileImageURL / phoneNumber. Called from the friends
    // tab so MyFriendsView can show statuses straight from cache next time.
    func refreshFriendStatuses(myUID: String) async {
        let db = DatabaseManager.shared
        let descriptor = FetchDescriptor<CachedFriend>()
        let uids = ((try? context.fetch(descriptor)) ?? []).map(\.uid)
        guard !uids.isEmpty else { return }

        await withTaskGroup(of: User?.self) { group in
            for uid in uids {
                group.addTask {
                    do {
                        return try await db.downloadUser(where: "User Identifier", isEqualTo: uid)
                    } catch {
                        return nil
                    }
                }
            }
            for await user in group {
                if let user, user.uid != myUID {
                    upsertFullFriend(user)
                }
            }
        }

        save()
    }

    // Clears the cache. Called on logout / account deletion.
    func wipe() {
        let f = FetchDescriptor<CachedFriend>()
        for friend in (try? context.fetch(f)) ?? [] { context.delete(friend) }
        let g = FetchDescriptor<CachedGroup>()
        for group in (try? context.fetch(g)) ?? [] { context.delete(group) }
        save()
    }
}
