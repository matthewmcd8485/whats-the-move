//
//  SwooshView.swift
//  wtm?
//

import SwiftUI
import FirebaseFirestore

struct SwooshView: View {
    let mood: NotificationTitle
    let groups: [SelectableGroup]
    let individuals: [Friend]
    let timeSensitive: Bool
    var onFinished: () -> Void = {}

    @State private var ringProgress: CGFloat = 0
    @State private var sent = false
    @State private var didTimeOut = false
    @State private var didFinish = false
    @State private var titleText = "sending..."
    @State private var subtitleText = "entering the matrix..."

    private let databaseManager = DatabaseManager.shared
    private let storageManager = StorageManager.shared

    var body: some View {
        ZStack {
            Color("backgroundColors").ignoresSafeArea()

            VStack(spacing: 0) {
                Text(titleText)
                    .font(.custom("SuperBasic-Bold", size: 48))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .padding(.top, 41)

                Text(subtitleText)
                    .font(.custom("SuperBasic-Regular", size: 20))
                    .foregroundStyle(Color("secondaryLabelColors"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                Spacer()

                ZStack {
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Color(red: 93 / 255, green: 138 / 255, blue: 166 / 255), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 240, height: 240)

                    Image(systemName: "checkmark")
                        .font(.system(size: 100, weight: .bold))
                        .foregroundStyle(Color("tertiaryLabelColors"))
                        .opacity(didFinish ? 1 : 0)
                }

                Spacer()
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                ringProgress = 1
            }
            startSending()
        }
    }

    private func startSending() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard !sent else { return }
            didTimeOut = true
            AlertManager.shared.showAlert(title: "error sending notifications", message: "check your internet connection and try again.")
            onFinished()
        }

        Task {
            await runSendFlow()
        }
    }

    private func runSendFlow() async {
        guard let uid = SecureStorage.uid,
              let name = UserDefaults.standard.string(forKey: "name") else { return }

        var allFriends = [Friend]()
        for selectableGroup in groups {
            for friend in selectableGroup.friends {
                if friend.uid != uid
                    && !ReportingManager.shared.userBlockedYou(theirUID: friend.uid)
                    && !ReportingManager.shared.userIsBlocked(theirUID: friend.uid) {
                    allFriends.append(friend)
                }
            }

            let requestID = UUID().uuidString
            let postedTime = Date()
            let expiresAt = Date(timeIntervalSinceNow: 7200)
            do {
                try await databaseManager.createBoredRequest(
                    requestID: requestID,
                    groupID: selectableGroup.group.groupID,
                    initiatedBy: name,
                    postedTime: postedTime,
                    expiresAt: expiresAt,
                    activity: mood.rawValue,
                    initiatorUID: uid,
                    initiatorSubstatus: "i'll be there!",
                    timeSensitive: timeSensitive
                )
            } catch {
                print("error uploading Firestore bored request for group: \(selectableGroup.group.groupID): \(error)")
            }
        }

        for friend in individuals {
            guard friend.uid != uid,
                  !ReportingManager.shared.userBlockedYou(theirUID: friend.uid),
                  !ReportingManager.shared.userIsBlocked(theirUID: friend.uid)
            else { continue }

            allFriends.append(friend)

            do {
                let groupID = try await databaseManager.ensureDirectGroup(myUID: uid, friendUID: friend.uid)
                let requestID = UUID().uuidString
                let postedTime = Date()
                let expiresAt = Date(timeIntervalSinceNow: 7200)
                try await databaseManager.createBoredRequest(
                    requestID: requestID,
                    groupID: groupID,
                    initiatedBy: name,
                    postedTime: postedTime,
                    expiresAt: expiresAt,
                    activity: mood.rawValue,
                    initiatorUID: uid,
                    initiatorSubstatus: "i'll be there!",
                    timeSensitive: timeSensitive
                )
            } catch {
                print("error uploading Firestore bored request for friend: \(friend.uid): \(error)")
            }
        }

        allFriends = allFriends.filterDuplicates { $0.uid == $1.uid }
        guard !allFriends.isEmpty else {
            print("allFriends list is empty")
            return
        }

        var allUsers = [User]()
        await withTaskGroup(of: User?.self) { group in
            for friend in allFriends {
                group.addTask {
                    do {
                        let user = try await DatabaseManager.shared.downloadUser(where: "User Identifier", isEqualTo: friend.uid)
                        return user.status != "do not disturb" ? user : nil
                    } catch {
                        print("error downloading user: \(error)")
                        return nil
                    }
                }
            }
            for await user in group {
                if let user { allUsers.append(user) }
            }
        }

        guard !allUsers.isEmpty else {
            print("allUsers list is empty")
            return
        }

        // Client-side fan-out removed; verify the mood image still exists, then finish.
        storageManager.downloadImageURL(imageName: mood.rawValue, collection: "mood images") { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    sent = true
                    if !didTimeOut { finishUp() }
                case .failure(let error):
                    print("error retrieving image URL: \(error)")
                    AlertManager.shared.showAlert(title: "couldn't send", message: "there was a problem sending your bored request. please try again.")
                    onFinished()
                }
            }
        }
    }

    @MainActor
    private func finishUp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            titleText = "done!"
            subtitleText = "your boredom might be cured"
            withAnimation(.easeInOut(duration: 0.5)) {
                didFinish = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            onFinished()
        }
    }
}

private final class SwooshHostingController: UIHostingController<SwooshView> {
    override init(rootView: SwooshView) {
        super.init(rootView: rootView)
        hidesBottomBarWhenPushed = true
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SwooshView {
    static func makeHostingController(mood: NotificationTitle, groups: [SelectableGroup], individuals: [Friend], timeSensitive: Bool) -> UIViewController {
        let hc = SwooshHostingController(rootView: SwooshView(mood: mood, groups: groups, individuals: individuals, timeSensitive: timeSensitive))
        hc.rootView = SwooshView(
            mood: mood,
            groups: groups,
            individuals: individuals,
            timeSensitive: timeSensitive,
            onFinished: { [weak hc] in
                hc?.navigationController?.popToRootViewController(animated: true)
            }
        )
        return hc
    }
}
