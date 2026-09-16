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
    let options: BoredSendOptions
    /// Identifies this one send. Request IDs are derived from it so running the
    /// flow twice overwrites the same documents instead of creating a second
    /// set — the Cloud Function triggers on create, so a repeat write doesn't
    /// fan out a duplicate push either.
    let sendID: UUID
    var onFinished: () -> Void = {}

    @State private var ringProgress: CGFloat = 0
    @State private var sent = false
    @State private var didTimeOut = false
    @State private var didFinish = false
    /// `onAppear` can fire more than once for the same screen. Sending twice
    /// would write duplicate requests — and so deliver duplicate pushes.
    @State private var didStartSending = false
    /// Set by the failure paths so the timeout doesn't stack a second alert on
    /// top of the one already on screen.
    @State private var didReportFailure = false
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

                    // Drawn on stroke-by-stroke once the ring has filled.
                    //
                    // Gated on `if` with an insertion transition rather than
                    // `.symbolEffect(.drawOn, isActive:)`: with `isActive` the
                    // tick was visible for the whole ring animation and drew
                    // *off* at the end — exactly backwards. The symbol only
                    // existing once we're done makes the direction impossible
                    // to get wrong.
                    if didFinish {
                        Image(systemName: "checkmark")
                            .font(.system(size: 100, weight: .bold))
                            .foregroundStyle(Color("tertiaryLabelColors"))
                            .transition(.symbolEffect(.drawOn))
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .onAppear {
            guard !didStartSending else { return }
            didStartSending = true

            withAnimation(.easeInOut(duration: 1.5)) {
                ringProgress = 1
            }
            startSending()
        }
    }

    private func startSending() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard !sent, !didReportFailure else { return }
            didTimeOut = true
            fail(title: "error sending notifications", message: "check your internet connection and try again.")
        }

        Task {
            await runSendFlow()
        }
    }

    /// Reports a send failure exactly once, then hands control back.
    @MainActor
    private func fail(title: String, message: String) {
        guard !didReportFailure else { return }
        didReportFailure = true
        AlertManager.shared.showAlert(title: title, message: message)
        onFinished()
    }

    @MainActor
    private func runSendFlow() async {
        guard let uid = SecureStorage.uid,
              let name = UserDefaults.standard.string(forKey: "name") else { return }

        // Resolve the activity artwork before writing anything. The URL gets
        // stored on each bored request so the push fan-out can attach it to the
        // notification without having to reach into Storage itself.
        let imageURL: String
        do {
            imageURL = try await storageManager.downloadImageURL(imageName: mood.rawValue, collection: "mood images")
        } catch {
            print("error retrieving image URL: \(error)")
            fail(title: "couldn't send", message: "there was a problem sending your bored request. please try again.")
            return
        }

        var didCreateRequest = false

        for selectableGroup in groups {
            let requestID = requestID(forGroup: selectableGroup.group.groupID)
            let postedTime = Date()
            let expiresAt = Date(timeIntervalSinceNow: options.duration.seconds)
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
                    timeSensitive: options.timeSensitive,
                    imageURL: imageURL
                )
                didCreateRequest = true
            } catch {
                print("error uploading Firestore bored request for group: \(selectableGroup.group.groupID): \(error)")
            }
        }

        for friend in individuals {
            guard friend.uid != uid,
                  !ReportingManager.shared.userBlockedYou(theirUID: friend.uid),
                  !ReportingManager.shared.userIsBlocked(theirUID: friend.uid)
            else { continue }

            do {
                let groupID = try await databaseManager.ensureDirectGroup(myUID: uid, friendUID: friend.uid)
                let requestID = requestID(forGroup: groupID)
                let postedTime = Date()
                let expiresAt = Date(timeIntervalSinceNow: options.duration.seconds)
                try await databaseManager.createBoredRequest(
                    requestID: requestID,
                    groupID: groupID,
                    initiatedBy: name,
                    postedTime: postedTime,
                    expiresAt: expiresAt,
                    activity: mood.rawValue,
                    initiatorUID: uid,
                    initiatorSubstatus: "i'll be there!",
                    timeSensitive: options.timeSensitive,
                    imageURL: imageURL
                )
                didCreateRequest = true
            } catch {
                print("error uploading Firestore bored request for friend: \(friend.uid): \(error)")
            }
        }

        // Recipient resolution — blocked pairs, "do not disturb" and stale
        // device tokens — is the Cloud Function's job now. Writing the request
        // documents is the whole of the client's work, so succeeding here is
        // what "sent" means.
        guard didCreateRequest else {
            print("no bored requests were created")
            fail(title: "couldn't send", message: "there was a problem sending your bored request. please try again.")
            return
        }

        sent = true
        if !didTimeOut { finishUp() }
    }

    /// Stable per send-and-group, so a repeated run lands on the same document.
    private func requestID(forGroup groupID: String) -> String {
        "\(sendID.uuidString)-\(groupID)"
    }

    @MainActor
    private func finishUp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            titleText = "done!"
            subtitleText = "your boredom might be cured"
            // The transition needs an animation in scope to run; the draw-on
            // effect supplies its own stroke timing within it.
            withAnimation { didFinish = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            onFinished()
        }
    }
}

