//
//  HomeTabView.swift
//  wtm?
//
//  The "home" tab: the big bored button, activity picker, recipient picker and
//  the sending animation.
//
//  These four screens were already SwiftUI but were pushed onto a bar-hidden
//  UINavigationController by hand, each with its own `makeHostingController`
//  factory, a UIGestureRecognizerDelegate shim to restore the pop gesture, and
//  a custom `arrow.left` button. This replaces all of that with one
//  NavigationStack and the system's navigation bar.
//

import SwiftUI

// MARK: - Routes

enum HomeRoute: Hashable {
    case activity
    case recipients(NotificationTitle)
    case sending(SendRequest)
}

/// Everything the send screen needs, carried on the navigation path itself.
///
/// The recipients used to live in separate `@State` next to the path, which
/// meant the `.sending` destination could be built before that state landed —
/// the send screen then saw empty lists, wrote no requests and reported a
/// failure. Identity is the `id` alone: `SelectableGroup` and `Friend` aren't
/// Hashable, and a fresh id per send is all the path needs to tell routes apart.
struct SendRequest: Hashable {
    let id = UUID()
    let mood: NotificationTitle
    let groups: [SelectableGroup]
    let individuals: [Friend]
    let timeSensitive: Bool

    static func == (lhs: SendRequest, rhs: SendRequest) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Root

struct HomeTabView: View {
    @State private var path: [HomeRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreenView(onBoredTapped: { path.append(.activity) })
                .navigationDestination(for: HomeRoute.self) { route in
                    destination(for: route)
                }
        }
        .tint(.wtmDarkBlue)
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .activity:
            ActivityView(onSelect: { path.append(.recipients($0)) })
        case .recipients(let mood):
            FriendSelectionView(mood: mood) { groups, friends, timeSensitive in
                path.append(.sending(SendRequest(
                    mood: mood,
                    groups: groups,
                    individuals: friends,
                    timeSensitive: timeSensitive
                )))
            }
        case .sending(let request):
            SwooshView(
                mood: request.mood,
                groups: request.groups,
                individuals: request.individuals,
                timeSensitive: request.timeSensitive,
                sendID: request.id,
                onFinished: { path.removeAll() }
            )
        }
    }
}

#Preview {
    HomeTabView()
}
