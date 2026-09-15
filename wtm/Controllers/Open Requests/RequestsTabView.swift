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
    /// `notifiedResponse` is set only when a notification's response button got
    /// here first, so the detail screen can show that answer before Firestore
    /// has confirmed it.
    case detail(requestID: String, notifiedResponse: BoredResponseChoice? = nil)
    case friendDetail(uid: String, name: String)
    case verify(phoneNumber: String)
}

// MARK: - Root

struct RequestsTabView: View {
    @State private var model = OpenRequestsModel()
    @State private var path: [RequestsTabRoute] = []
    @Environment(DeepLinkRouter.self) private var deepLinks

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
        .task(id: deepLinks.boredRequest) { await openNotifiedRequest() }
    }

    /// Opens the request a notification pointed at.
    ///
    /// The list may not have loaded yet — tapping a push launches the app
    /// straight into this — so fetch before concluding the request isn't there.
    private func openNotifiedRequest() async {
        guard let target = deepLinks.boredRequest else { return }

        if !model.items.contains(where: { $0.id == target.requestID }) {
            await model.load()
        }

        // Found or not, the link has been acted on. Leaving it set would push
        // the same request again on every return to this tab.
        deepLinks.clearBoredRequest()

        guard model.items.contains(where: { $0.id == target.requestID }) else {
            Log.push.info("the request a notification pointed at is no longer open")
            return
        }

        // Replaces the stack rather than appending: a second push shouldn't
        // stack requests on top of each other.
        path = [.detail(requestID: target.requestID, notifiedResponse: target.chosenResponse)]
    }

    @ViewBuilder
    private func destination(for route: RequestsTabRoute) -> some View {
        switch route {
        case .detail(let requestID, let notifiedResponse):
            if let item = model.items.first(where: { $0.id == requestID }) {
                RequestDetailView(
                    group: item.group,
                    request: item.request,
                    notifiedResponse: notifiedResponse,
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

/// How a request is titled, which works differently for a direct one.
///
/// A direct group's stored `name` isn't anything a person chose — it's the
/// literal "direct" — and the request document records only the *sender's*
/// name. So a direct request read as your own name on the ones you sent, and as
/// "direct" anywhere the group name was used. Both ends should name the person
/// on the *other* end of it, with a charm saying which way it went.
@MainActor
struct RequestPresentation {
    let title: String
    /// "direct to you" / "direct to them". `nil` for a group request, which
    /// needs no explaining.
    let directionCharm: String?
    /// The line under the title: who wants what.
    let detail: String

    init(group: FriendGroup, request: BoredRequest) {
        guard group.isDirectGroup else {
            title = group.name
            directionCharm = nil
            detail = "\(request.initiatedBy) \(request.activity)"
            return
        }

        detail = request.activity

        // Only the sender's *name* is stored on the request, so "did I send
        // this?" has to be a name comparison. Inside a two-person group that
        // would only misfire if both people shared a name.
        let myName = UserDefaults.standard.string(forKey: "name") ?? ""
        let iSentIt = !myName.isEmpty
            && request.initiatedBy.caseInsensitiveCompare(myName) == .orderedSame

        guard iSentIt else {
            title = request.initiatedBy
            directionCharm = "direct to you"
            return
        }

        // I sent it, so the other member of the pair is who it's addressed to.
        let otherUID = (group.people ?? []).first { $0 != SecureStorage.uid }
        title = otherUID.flatMap { LocalCacheManager.shared.cachedName(forUID: $0) } ?? "your friend"
        directionCharm = "direct to them"
    }
}

/// A small pill under a title on the artwork, e.g. which way a direct request
/// was sent.
struct RequestCharm: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.wtmBold(11, relativeTo: .caption2))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.22), in: .capsule)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
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

    private var presentation: RequestPresentation {
        RequestPresentation(group: group, request: request)
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
                VStack(alignment: .leading, spacing: 5) {
                    Text(presentation.title.lowercased())
                        .font(.wtmBold(24, relativeTo: .title2))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let charm = presentation.directionCharm {
                        RequestCharm(text: charm)
                    }
                }
                .padding(14)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(presentation.detail.lowercased())
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

    func load(
        group: FriendGroup,
        request: BoredRequest,
        notifiedResponse: BoredResponseChoice? = nil
    ) async {
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

        // An answer given from the notification won't have reached Firestore by
        // the time this read comes back, so show what was actually chosen
        // rather than the "no response" the document still says.
        if let notifiedResponse {
            apply(notifiedResponse)
        }
    }

    /// Writes a response into your own row without going near the network.
    private func apply(_ choice: BoredResponseChoice) {
        guard let uid = SecureStorage.uid,
              let index = people.firstIndex(where: { $0.user.uid == uid }) else { return }
        people[index].responseStatus = choice.status
        people[index].responseSubstatus = choice.substatus
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
                .sorted { $0.name.sortsBefore($1.name) }
                .map { user in
                    let status = document.get(FirestoreKeys.BoredRequest.availabilityField(forUID: user.uid)) as? String ?? BoredResponseCategory.noResponse
                    let substatus = document.get(FirestoreKeys.BoredRequest.substatusField(forUID: user.uid)) as? String ?? BoredResponseCategory.noResponse
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
            apply(BoredResponseChoice(status: status, substatus: substatus))
        } catch {
            Log.database.error("error updating response: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct RequestDetailView: View {
    let group: FriendGroup
    let request: BoredRequest
    /// The answer already given from a notification's response button, if this
    /// screen was opened by one.
    var notifiedResponse: BoredResponseChoice?
    var onOpenFriend: (User) -> Void = { _ in }
    var onOpenStranger: (User) -> Void = { _ in }

    /// Which response editor is open, one level deeper than this screen.
    enum ResponseEdit: Hashable {
        /// The canned messages for a category.
        case presets(BoredResponseCategory)
        /// Pick a category and write your own message.
        case custom
    }

    @Environment(\.dismiss) private var dismiss
    @State private var model = RequestDetailModel()
    @State private var showStatusChoice = false
    @State private var responseEdit: ResponseEdit?
    /// So arriving back from the editor doesn't re-open it.
    @State private var didFollowNotifiedResponse = false
    @State private var notice: (title: String, message: String)?
    @State private var showNotice = false

    private var activity: NotificationTitle {
        NotificationTitle(activity: request.activity)
    }

    private var presentation: RequestPresentation {
        RequestPresentation(group: group, request: request)
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
            isPresented: Binding(get: { responseEdit != nil }, set: { if !$0 { responseEdit = nil } })
        ) {
            responseEditor
        }
        .task { await model.load(group: group, request: request, notifiedResponse: notifiedResponse) }
        .onAppear(perform: followNotifiedResponse)
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

    /// The response choices, shared by the toolbar menu and the dialog that the
    /// "you" row opens.
    @ViewBuilder
    private var responseOptions: some View {
        ForEach(BoredResponseCategory.presetCategories) { category in
            Button(category.menuLabel, systemImage: category.iconName) {
                responseEdit = .presets(category)
            }
        }
        Button("custom...", systemImage: "square.and.pencil") { responseEdit = .custom }
    }

    @ViewBuilder
    private var responseEditor: some View {
        switch responseEdit {
        case .presets(let category):
            ChangeResponseView(category: category) { substatus in
                submit(category: category, substatus: substatus)
            }
        case .custom:
            CustomResponseView { category, substatus in
                submit(category: category, substatus: substatus)
            }
        case nil:
            EmptyView()
        }
    }

    private func submit(category: BoredResponseCategory, substatus: String) {
        Task {
            await model.submit(
                status: category.rawValue,
                substatus: substatus,
                group: group,
                request: request
            )
            responseEdit = nil
        }
    }

    /// A notification's response button already answered the category, so land
    /// on that category's message list — one level deeper than the request —
    /// so the reply can be refined in a single tap.
    private func followNotifiedResponse() {
        guard !didFollowNotifiedResponse,
              let notifiedResponse,
              let category = BoredResponseCategory(rawValue: notifiedResponse.status),
              BoredResponseCategory.presetCategories.contains(category) else { return }

        didFollowNotifiedResponse = true
        responseEdit = .presets(category)
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
                    Text(presentation.title.lowercased())
                        .font(.wtmBold(34, relativeTo: .largeTitle))

                    if let charm = presentation.directionCharm {
                        RequestCharm(text: charm)
                            .padding(.bottom, 2)
                    }

                    Text(presentation.detail.lowercased())
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

    var body: some View {
        HStack(spacing: 12) {
            BoredResponseSymbol(category: BoredResponseCategory(rawValue: person.responseStatus), size: 24)
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
    let category: BoredResponseCategory
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ResponseCategoryHeading(category: category)

            Text("pick a message to go with your response.")
                .font(.wtmSubtitle)
                .foregroundStyle(Color.wtmSecondaryLabel)
                .padding(.horizontal, WTMLayout.sideMargin)
                .padding(.top, 8)

            List(category.presetMessages, id: \.self) { option in
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

/// A response category's glyph.
///
/// One view for every place a category is drawn — the response list, both
/// editor headings and the category picker — so the rendering mode can't drift
/// between them. Hierarchical, so each glyph reads as one tinted object with
/// depth in it rather than a flat stamp.
struct BoredResponseSymbol: View {
    /// `nil` for someone who hasn't answered, which isn't a category.
    let category: BoredResponseCategory?
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: category?.iconName ?? "questionmark.circle")
            .font(.system(size: size, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(category?.color ?? Color.gray)
    }
}

/// The icon-and-title heading both response editors share.
struct ResponseCategoryHeading: View {
    let category: BoredResponseCategory

    var body: some View {
        HStack(spacing: 12) {
            BoredResponseSymbol(category: category, size: 40)
                .contentTransition(.symbolEffect(.replace))
            Text(category.headline)
                .font(.wtmBold(28, relativeTo: .title))
                .foregroundStyle(Color.wtmDarkBlue)
                // Rolls over rather than cross-fading, so the wording turns
                // over in step with the symbol swapping beside it.
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, WTMLayout.sideMargin)
        .padding(.top, 8)
        // Both halves change together when the category does, so the animation
        // belongs here rather than on whichever screen is driving it.
        .animation(.snappy(duration: 0.25), value: category)
    }
}

// MARK: - Custom response

/// Pick a category — including the uncategorised purple one — and write your
/// own message instead of taking one off the canned list.
struct CustomResponseView: View {
    /// Called with the chosen category and the trimmed message.
    let onSend: (BoredResponseCategory, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: BoredResponseCategory = .uncategorized
    @State private var message = ""
    @State private var showProfanityWarning = false
    @FocusState private var isWriting: Bool

    /// Short because it has to survive a notification banner, where anything
    /// longer is truncated mid-word anyway.
    private static let characterLimit = 50

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            // Bottom layer, so a tap on any empty part of the screen puts the
            // keyboard away.
            Color.wtmBackground
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { isWriting = false }

            VStack(alignment: .leading, spacing: 0) {
                ResponseCategoryHeading(category: category)

                Text("say whatever you want, then pick how free you are.")
                    .font(.wtmSubtitle)
                    .foregroundStyle(Color.wtmSecondaryLabel)
                    .padding(.horizontal, WTMLayout.sideMargin)
                    .padding(.top, 8)

                categoryPicker
                    .padding(.horizontal, WTMLayout.sideMargin)
                    .padding(.top, 20)

                messageField
                    .padding(.horizontal, WTMLayout.sideMargin)
                    .padding(.top, 20)

                PrimaryActionButton(title: "send it") { send() }
                    .padding(.horizontal, WTMLayout.sideMargin)
                    .padding(.top, 20)
                    .opacity(trimmedMessage.isEmpty ? 0.4 : 1)
                    .disabled(trimmedMessage.isEmpty)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("ok, potty mouth", isPresented: $showProfanityWarning) {
            Button("fine", role: .cancel) {}
        } message: {
            Text("there are some less-than-ideal words in there.\n\nyour friends get this as a notification, so keep it clean — or turn on explicit mode in settings.")
        }
        .onAppear { isWriting = true }
    }

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(BoredResponseCategory.allCases) { option in
                Button {
                    category = option
                } label: {
                    VStack(spacing: 6) {
                        BoredResponseSymbol(category: option, size: 24)
                        Text(option.shortLabel)
                            .font(.wtmRegular(12, relativeTo: .caption))
                            .foregroundStyle(Color.wtmSecondaryLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: WTMLayout.cornerRadius)
                            .fill(category == option ? option.color.opacity(0.18) : Color.wtmGroupedCard)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: WTMLayout.cornerRadius)
                            .strokeBorder(category == option ? option.color : .clear, lineWidth: 2)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.shortLabel)
                .accessibilityAddTraits(category == option ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(.snappy(duration: 0.2), value: category)
    }

    private var messageField: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField("say something", text: $message, axis: .vertical)
                .font(.wtmRegular(18, relativeTo: .body))
                .foregroundStyle(Color.wtmDarkBlue)
                .tint(Color.wtmDarkBlue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(1...3)
                .focused($isWriting)
                .submitLabel(.done)
                .onSubmit { send() }
                .padding(14)
                .background(Color.wtmGroupedCard, in: RoundedRectangle(cornerRadius: WTMLayout.cornerRadius))
                .onChange(of: message) { _, newValue in
                    // Trimmed as you type rather than refused on send: the cap
                    // is about what fits in a banner, and silently losing the
                    // end of a sentence at submit time is worse than seeing it
                    // stop.
                    if newValue.count > Self.characterLimit {
                        message = String(newValue.prefix(Self.characterLimit))
                    }
                }

            Text("\(message.count)/\(Self.characterLimit)")
                .font(.wtmFootnote)
                .foregroundStyle(
                    message.count >= Self.characterLimit ? Color.wtmDarkRed : Color.wtmSecondaryLabel
                )
                .monospacedDigit()
        }
    }

    private func send() {
        let text = trimmedMessage
        guard !text.isEmpty else { return }

        // Explicit mode is exactly the switch for opting out of this, so it's
        // the one thing that skips the check. Everyone else's message is
        // filtered, because it goes out to the whole group as a push.
        if !UserDefaults.standard.bool(forKey: "explicit"),
           ProfanityManager.shared.checkForProfanity(in: text) {
            showProfanityWarning = true
            return
        }

        isWriting = false
        onSend(category, text)
        dismiss()
    }
}

#Preview {
    RequestsTabView()
}
