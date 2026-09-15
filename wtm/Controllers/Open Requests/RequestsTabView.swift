//
//  RequestsTabView.swift
//  wtm?
//
//  The "requests" tab: open bored requests, the responses to one, and
//  picking your own response. Replaces BoredRequestsViewController,
//  BoredRequestResponseViewController and ChangeResponseViewController.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Routes

/// Routes carry identifiers rather than models. `BoredRequest` and
/// `FriendGroup` aren't Hashable, and making them so would mean giving `User` a
/// `hash(into:)` consistent with its existing `==` — which compares phone
/// numbers only. Keying off the request id and looking the pair back up avoids
/// putting that oddity on a navigation path.
enum RequestsTabRoute: Hashable {
    case detail(requestID: String)
    case friendDetail(uid: String, name: String)
    case verify(phoneNumber: String)
}

// MARK: - Root

struct RequestsTabView: View {
    @State private var model = OpenRequestsModel()
    @State private var path: [RequestsTabRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            OpenRequestsView(
                model: model,
                onSelect: { path.append(.detail(requestID: $0.id)) }
            )
            .navigationDestination(for: RequestsTabRoute.self) { route in
                destination(for: route)
            }
        }
        .tint(.wtmDarkBlue)
    }

    @ViewBuilder
    private func destination(for route: RequestsTabRoute) -> some View {
        switch route {
        case .detail(let requestID):
            if let item = model.items.first(where: { $0.id == requestID }) {
                RequestDetailView(
                    group: item.group,
                    request: item.request,
                    onOpenFriend: { path.append(.friendDetail(uid: $0.uid, name: $0.name)) },
                    onOpenStranger: { path.append(.verify(phoneNumber: $0.phoneNumber)) }
                )
            }
        case .friendDetail(let uid, let name):
            FriendDetailView(uid: uid, name: name)
        case .verify(let phoneNumber):
            FriendVerifyView(phoneNumber: phoneNumber, onFinished: { path.removeLast() })
        }
    }
}

// MARK: - Open requests list

@Observable
@MainActor
final class OpenRequestsModel {
    /// A request paired with the group it belongs to.
    struct Item: Identifiable {
        let group: FriendGroup
        let request: BoredRequest
        var id: String { request.requestID }
    }

    var items: [Item] = []
    var isLoading = true

    func load() async {
        defer { isLoading = false }
        guard let uid = SecureStorage.uid else { return }

        do {
            let groups = try await DatabaseManager.shared.downloadAllGroups(uid: uid)
            UserDefaults.standard.set(groups.map(\.groupID), forKey: "groupsUID")

            // Requests older than two hours have expired.
            let cutoff = Timestamp(date: Date(timeIntervalSinceNow: -7200))
            let requests = try await DatabaseManager.shared.downloadBoredRequests(
                forGroupIDs: groups.map(\.groupID),
                notExpiredSince: cutoff
            )

            // Index the groups so pairing is a lookup rather than the old
            // nested loop over both collections.
            let groupsByID = Dictionary(
                groups.map { ($0.groupID, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            items = requests
                .compactMap { request in
                    groupsByID[request.groupID].map { Item(group: $0, request: request) }
                }
                .sorted { $0.request.postedTime > $1.request.postedTime }
        } catch {
            Log.database.error("error loading bored requests: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct OpenRequestsView: View {
    let model: OpenRequestsModel
    var onSelect: (OpenRequestsModel.Item) -> Void = { _ in }

    var body: some View {
        ScreenScaffold(title: "requests", subtitle: "your friends are bored. fix that!", scrolls: false) {
            content
        }
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            CenteredMessage(text: "loading...", color: .wtmDarkBlue)
            Spacer()
        } else if model.items.isEmpty {
            CenteredMessage(
                text: "no one is bored right now.\n\nenjoy the peace and quiet, i guess.",
                font: .wtmRegular(18, relativeTo: .body)
            )
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(model.items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            RequestCardView(group: item.group, request: item.request)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, WTMLayout.sideMargin)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }
}

/// The artwork card `BoredRequestTableViewCell` used to draw.
struct RequestCardView: View {
    let group: FriendGroup
    let request: BoredRequest

    private var activity: NotificationTitle {
        NotificationTitle(activity: request.activity)
    }

    private var headline: String {
        group.isDirectGroup
            ? request.initiatedBy
            : group.name
    }

    private var detail: String {
        group.isDirectGroup
            ? request.activity
            : "\(request.initiatedBy) \(request.activity)"
    }

    var body: some View {
        // The image is sized and clipped *before* anything is composited on
        // top. It used to sit in a `ZStack(alignment: .bottomLeading)`, which
        // takes its size from the overflowing `scaledToFill` image — so the
        // gradient's dark end and the text were both laid out past the visible
        // 150pt and clipped away, leaving a bare undimmed photo.
        Image(activity.imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()
            .dimmedArtwork()
            .overlay {
                // On top of the uniform dim, a little extra at the two edges
                // where the text sits. Several stops so the ramp doesn't band.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.3), location: 0),
                        .init(color: .black.opacity(0.08), location: 0.3),
                        .init(color: .black.opacity(0.08), location: 0.55),
                        .init(color: .black.opacity(0.28), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) {
                Text(headline.lowercased())
                    .font(.wtmBold(24, relativeTo: .title2))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(14)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(detail.lowercased())
                        .font(.wtmRegular(15, relativeTo: .subheadline))
                    Text("expires at \(request.expiresAt.toString(dateFormat: "h:mm a"))")
                        .font(.wtmThin(13, relativeTo: .footnote))
                }
                .foregroundStyle(.white)
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: WTMLayout.cornerRadius))
            .contentShape(.rect)
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Request detail

@Observable
@MainActor
final class RequestDetailModel {
    var people: [BoredRequestUser] = []
    var isLoading = true
    var failed = false

    private let db = Firestore.firestore()

    func load(group: FriendGroup, request: BoredRequest) async {
        defer { isLoading = false }
        let uids = group.people ?? []
        guard !uids.isEmpty else { return }

        // Fetch every member concurrently instead of the old serial loop that
        // only kicked off the response query on the last callback.
        let users = await withTaskGroup(of: User?.self) { tasks in
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

        guard !users.isEmpty else {
            failed = true
            return
        }

        await applyResponses(to: users, group: group, request: request)
    }

    private func applyResponses(to users: [User], group: FriendGroup, request: BoredRequest) async {
        do {
            let snapshot = try await db
                .collection(FirestoreKeys.Collection.friendGroups)
                .document(group.groupID)
                .collection(FirestoreKeys.Collection.boredRequests)
                .whereField(FirestoreKeys.BoredRequest.requestIdentifier, isEqualTo: request.requestID)
                .getDocuments()

            guard let document = snapshot.documents.first else {
                failed = true
                return
            }

            people = users
                .sorted { $0.name < $1.name }
                .map { user in
                    let status = document.get(FirestoreKeys.BoredRequest.availabilityField(forUID: user.uid)) as? String ?? "no response"
                    let substatus = document.get(FirestoreKeys.BoredRequest.substatusField(forUID: user.uid)) as? String ?? "no response"
                    return BoredRequestUser(user: user, responseStatus: status, responseSubstatus: substatus)
                }
        } catch {
            Log.database.error("error downloading responses: \(error.localizedDescription, privacy: .public)")
            failed = true
        }
    }

    func submit(status: String, substatus: String, group: FriendGroup, request: BoredRequest) async {
        guard let uid = SecureStorage.uid else { return }
        do {
            try await DatabaseManager.shared.updateBoredRequestResponse(
                groupID: group.groupID,
                requestID: request.requestID,
                uid: uid,
                status: status,
                substatus: substatus
            )
            // Reflect it locally so the list updates without a refetch.
            if let index = people.firstIndex(where: { $0.user.uid == uid }) {
                people[index].responseStatus = status
                people[index].responseSubstatus = substatus
            }
        } catch {
            Log.database.error("error updating response: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct RequestDetailView: View {
    let group: FriendGroup
    let request: BoredRequest
    var onOpenFriend: (User) -> Void = { _ in }
    var onOpenStranger: (User) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var model = RequestDetailModel()
    @State private var showStatusChoice = false
    @State private var pendingStatus: String?
    @State private var notice: (title: String, message: String)?
    @State private var showNotice = false

    private var activity: NotificationTitle {
        NotificationTitle(activity: request.activity)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            list
        }
        .background(Color.wtmBackground)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // A Menu rather than a button driving the dialog, so the options
            // unfold from the button itself instead of being thrown into the
            // middle of the screen.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    responseOptions
                } label: {
                    Image(systemName: "bubble.and.pencil")
                }
                .plainToolbarSymbol()
                .accessibilityLabel("reply")
            }
        }
        // Still here for the other way in — tapping your own row, which can't
        // open a Menu programmatically.
        .confirmationDialog("change your response", isPresented: $showStatusChoice, titleVisibility: .visible) {
            responseOptions
            Button("oops, cancel", role: .cancel) {}
        } message: {
            Text("are you free today?")
        }
        .navigationDestination(
            isPresented: Binding(get: { pendingStatus != nil }, set: { if !$0 { pendingStatus = nil } })
        ) {
            if let status = pendingStatus {
                ChangeResponseView(status: status) { substatus in
                    Task {
                        await model.submit(status: status, substatus: substatus, group: group, request: request)
                        pendingStatus = nil
                    }
                }
            }
        }
        .task { await model.load(group: group, request: request) }
        .alert("error loading request", isPresented: Bindable(model).failed) {
            Button("okay") { dismiss() }
        } message: {
            Text("there was an error loading this request. please try again later.")
        }
        .alert(notice?.title ?? "", isPresented: $showNotice) {
            Button("okay", role: .cancel) {}
        } message: {
            Text(notice?.message ?? "")
        }
    }

    /// The three response choices, shared by the toolbar menu and the dialog
    /// that the "you" row opens.
    @ViewBuilder
    private var responseOptions: some View {
        Button("yeah, i'm free", systemImage: "checkmark.circle") { pendingStatus = "available" }
        Button("mmm, maybe?", systemImage: "exclamationmark.circle") { pendingStatus = "busy" }
        Button("no, i'm not free", systemImage: "nosign") { pendingStatus = "not available" }
    }

    /// Artwork banner with the group name, activity and expiry, fading into the
    /// background. The storyboard achieved this with two CAGradientLayer masks
    /// applied in `viewDidLoad`.
    private var header: some View {
        // Sized and clipped before compositing, for the same reason as the
        // cards: a ZStack around an overflowing `scaledToFill` image anchors
        // its other children to the image's bounds rather than the visible
        // frame, which is why only the group name showed and the gradient
        // ended in a hard edge instead of fading out.
        Image(activity.imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            // Taller than the content needs, so the artwork reaches down into
            // what was empty page rather than stopping short of the list.
            .frame(height: 400)
            .clipped()
            .dimmedArtwork()
            .overlay { legibilityScrim }
            .overlay(alignment: .bottom) { pageFade }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text((group.isDirectGroup ? request.initiatedBy : group.name).lowercased())
                        .font(.wtmBold(34, relativeTo: .largeTitle))
                    Text((group.isDirectGroup ? request.activity : "\(request.initiatedBy) \(request.activity)").lowercased())
                        .font(.wtmRegular(18, relativeTo: .body))
                    Text("this request expires at \(request.expiresAt.toString(dateFormat: "h:mm a"))")
                        .font(.wtmThin(13, relativeTo: .footnote))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, WTMLayout.sideMargin)
                // Sits above the fade, so the text stays on the dark part of
                // the scrim and reads in both light and dark appearance.
                .padding(.bottom, 170)
            }
            .ignoresSafeArea(edges: .top)
    }

    /// Extra darkening on top of the uniform dim, concentrated in the band the
    /// three lines of text occupy — roughly 0.38 to 0.62 down the header, given
    /// a 400pt frame and 170pt of bottom padding. The previous version put its
    /// darkest stops at the very top and bottom instead, which is exactly where
    /// there is no text, and left "the does" sitting on open sky.
    ///
    /// Several stops rather than two: a straight ramp over this distance bands.
    private var legibilityScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.3), location: 0),
                .init(color: .black.opacity(0.1), location: 0.2),
                .init(color: .black.opacity(0.32), location: 0.36),
                .init(color: .black.opacity(0.38), location: 0.5),
                .init(color: .black.opacity(0.32), location: 0.64),
                .init(color: .black.opacity(0.1), location: 0.82)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Dissolves the bottom of the artwork into the page. The opacity ramp is
    /// deliberately uneven — easing it in slowly and finishing fast reads as a
    /// smooth blend, where an even ramp shows a visible seam where it starts.
    private var pageFade: some View {
        LinearGradient(
            stops: [
                .init(color: Color.wtmBackground.opacity(0), location: 0),
                .init(color: Color.wtmBackground.opacity(0.12), location: 0.28),
                .init(color: Color.wtmBackground.opacity(0.4), location: 0.52),
                .init(color: Color.wtmBackground.opacity(0.75), location: 0.72),
                .init(color: Color.wtmBackground.opacity(0.95), location: 0.88),
                .init(color: Color.wtmBackground, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 220)
    }

    @ViewBuilder
    private var list: some View {
        if model.isLoading {
            CenteredMessage(text: "loading...", color: .wtmDarkBlue)
            Spacer()
        } else {
            List(model.people, id: \.user.uid) { person in
                Button {
                    open(person.user)
                } label: {
                    ResponseRowView(person: person)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.wtmBackground)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            // `.insetGrouped` reserves room for a section header above the
            // first row, which is what left a band of empty page between the
            // artwork and the names. `.plain` plus a zeroed top margin puts
            // the first row directly under the header.
            .listStyle(.plain)
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
        }
    }

    private func open(_ user: User) {
        if user.uid == SecureStorage.uid {
            showStatusChoice = true
            return
        }
        guard user.name != "user deleted" else {
            return notify("user deleted", "sorry, we don't specialize in communicating with ghosts.")
        }
        if ReportingManager.shared.userIsBlocked(theirUID: user.uid)
            || ReportingManager.shared.userBlockedYou(theirUID: user.uid) {
            return notify("user blocked", "either you blocked this person, or they blocked you.\n\nquit it with these toxic friends!")
        }

        let friends = UserDefaults.standard.stringArray(forKey: "friendsUID") ?? []
        if friends.contains(user.uid) {
            onOpenFriend(user)
        } else {
            onOpenStranger(user)
        }
    }

    private func notify(_ title: String, _ message: String) {
        notice = (title, message)
        showNotice = true
    }
}

/// One person's response, as `BoredResponseTableViewCell` drew it.
struct ResponseRowView: View {
    let person: BoredRequestUser

    private var icon: (name: String, color: Color) {
        switch person.responseStatus {
        case "available": ("checkmark.circle", .green)
        case "busy": ("exclamationmark.circle", .wtmDarkYellow)
        case "not available": ("nosign", .red)
        default: ("questionmark.circle", .gray)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon.name)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(icon.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(person.user.uid == SecureStorage.uid ? "you" : person.user.name.lowercased())
                    .font(.wtmBold(20, relativeTo: .body))
                    .foregroundStyle(Color.wtmDarkBlue)
                    .lineLimit(1)
                Text(person.responseSubstatus)
                    .font(.wtmThin(12, relativeTo: .caption))
                    .foregroundStyle(Color.wtmSecondaryLabel)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
        }
        .contentShape(.rect)
    }
}

// MARK: - Change response

struct ChangeResponseView: View {
    let status: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var presentation: (title: String, icon: String, color: Color, options: [String]) {
        switch status {
        case "available":
            ("you are available", "checkmark.circle", .green, [
                "lmk what time", "sounds good", "i'll be there!", "i'll drive",
                "on my way!", "ok!", "so excited!", "can't wait to see you all", "joe"
            ])
        case "busy":
            ("you are busy", "exclamationmark.circle", .wtmDarkYellow, [
                "already have plans", "maybe later?", "tomorrow would work better",
                "don't know what's happening", "maybe when i get off work",
                "gotta ask my parents", "won't have a car today", "ask me again in an hour", "joe"
            ])
        default:
            ("you are not available", "nosign", .red, [
                "already have plans today", "i'm not in town", "i don't like you",
                "i'm not free today", "call me when i care", "leave me alone",
                "at work all day", "got dragged into some other stuff", "joe"
            ])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: presentation.icon)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(presentation.color)
                Text(presentation.title)
                    .font(.wtmBold(28, relativeTo: .title))
                    .foregroundStyle(Color.wtmDarkBlue)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, WTMLayout.sideMargin)
            .padding(.top, 8)

            Text("pick a message to go with your response.")
                .font(.wtmSubtitle)
                .foregroundStyle(Color.wtmSecondaryLabel)
                .padding(.horizontal, WTMLayout.sideMargin)
                .padding(.top, 8)

            List(presentation.options, id: \.self) { option in
                Button {
                    onPick(option)
                    dismiss()
                } label: {
                    HStack {
                        Text(option)
                            .font(.wtmRegular(18, relativeTo: .body))
                            .foregroundStyle(Color.wtmDarkBlue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                    .frame(minHeight: 40)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.wtmBackground)
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wtmBackground)
    }
}

#Preview {
    RequestsTabView()
}
