//
//  HomeScreenView.swift
//  wtm?
//

import SwiftUI
import FirebaseRemoteConfig

struct HomeScreenView: View {
    var onBoredTapped: () -> Void = {}

    @State private var showNoRecipientsAlert = false
    @State private var showTimeoutAlert = false
    @State private var showNewVersionAlert = false
    @State private var newVersionString = ""

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color("lightBlueOnLight").ignoresSafeArea()

                Text("wtm?")
                    .font(.custom("SuperBasic-Bold", size: 100))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .multilineTextAlignment(.center)
                    .frame(width: 358)
                    .position(x: proxy.size.width / 2, y: 107 + 77.5)

                Button(action: handleBoredTap) {
                    Image("boredButton")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 275, height: 275)
                        .clipShape(Circle())
                }
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2 + 55)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await checkForNewRelease() }
        .alert("no friends yet", isPresented: $showNoRecipientsAlert) {
            Button("okay", role: .cancel) {}
        } message: {
            Text("you need at least one friend or friend group before you can send requests.\n\ngo to the \"friends\" tab to add someone.")
        }
        .alert("nice try, dingbat", isPresented: $showTimeoutAlert) {
            Button("yeah, i'm sad and lonely", role: .cancel) {}
        } message: {
            Text("you're still in timeout from when you sent a mass notification to all of your friends. \n\nwe understand how sad and lonely you must be. but if your friends actually cared about you, we wouldn't be in this predicament, would we?\n\nthink about that while you wait until your timeout is over.")
        }
        .alert("new version available", isPresented: $showNewVersionAlert) {
            Button("no, screw you", role: .cancel) {}
            Button("ok, bet") {
                guard let url = URL(string: "https://apps.apple.com/us/app/whats-the-move/id1574130925") else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text("\"wtm?\" v\(newVersionString) is now available on the app store. please visit the app store to update it!")
        }
    }

    private func handleBoredTap() {
        guard LocalCacheManager.shared.hasAnyRecipients() else {
            showNoRecipientsAlert = true
            return
        }

        if let sendAllDate = UserDefaults.standard.object(forKey: "sendToAllDate") as? Date,
           let diff = Calendar.current.dateComponents([.hour], from: sendAllDate, to: Date()).hour,
           diff < 2 {
            showTimeoutAlert = true
            return
        }

        onBoredTapped()
    }

    /// Offers the App Store when a newer version has been published.
    ///
    /// The fetch is the point. This used to read `configValue` straight off
    /// `RemoteConfig.remoteConfig()` without ever fetching, and nothing else in
    /// the app fetches either — so it was reading a local store that had never
    /// been populated and no defaults registered. `latestVersion` came back
    /// empty every time, the `isEmpty` guard returned, and this alert could
    /// never appear at all.
    private func checkForNewRelease() async {
        let config = RemoteConfig.remoteConfig()
        do {
            // Respects the default 12-hour minimum interval, so this is at most
            // one request per launch and usually zero. Lower
            // `minimumFetchInterval` on a debug build if you need to see a
            // change immediately.
            _ = try await config.fetchAndActivate()
        } catch {
            Log.ui.error("couldn't fetch remote config: \(error.localizedDescription, privacy: .public)")
            return
        }

        let latestVersion = config.configValue(forKey: "latestVersion").stringValue
        guard !latestVersion.isEmpty,
              UIApplication.appVersion().compare(latestVersion, options: .numeric) == .orderedAscending else { return }

        newVersionString = latestVersion
        showNewVersionAlert = true
    }
}

