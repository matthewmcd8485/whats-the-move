//
//  OnboardingModel.swift
//  wtm?
//
//  Drives sign-up / sign-in. Replaces the logic that was spread across
//  WelcomeViewController, PhoneNumberViewController, VerificationViewController,
//  NameViewController and FinishingUpViewController.
//
//  Three things changed beyond the UIKit-to-SwiftUI move:
//
//  * The Firebase verification ID is held in memory here instead of being
//    written to UserDefaults. It's short-lived auth material and there's no
//    reason for it to outlive the flow or sit in a plist.
//
//  * The "did it hang?" check is a real timeout. Each screen previously
//    scheduled a 10-second `DispatchQueue.main.asyncAfter` that fired whether
//    or not the request had already succeeded, and decided what to do by
//    reading a `continuing` flag that several code paths forgot to set.
//
//  * Failures surface as thrown errors with a message, so no path can leave a
//    spinner running forever the way the old `return`-without-dismissing did.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseStorage
import UserNotifications

// MARK: - Errors

enum OnboardingError: LocalizedError {
    case emptyPhoneNumber
    case missingPlusPrefix
    case emptyCode
    case missingVerificationID
    case emptyName
    case nameTooLong
    case reservedName
    case profanity
    case missingProfileDetails
    case timedOut
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .emptyPhoneNumber:
            "please enter your phone number in the field."
        case .missingPlusPrefix:
            "please include the \"+\" at the beginning of the phone number."
        case .emptyCode:
            "please enter the verification code that was sent to your phone."
        case .missingVerificationID:
            "we lost track of your verification request. please request a new code."
        case .emptyName:
            "please enter your name in the field."
        case .nameTooLong:
            "come on, dude. read the directions!"
        case .reservedName:
            "please enter a different name in the field."
        case .profanity:
            "there are some less-than-ideal words used in your name. please make sure your name is accurate and appropriate."
        case .missingProfileDetails:
            "some of your information was not found. please try again."
        case .timedOut:
            "something went wrong here. check your internet connection and try again."
        case .underlying(let message):
            message
        }
    }

    /// Title shown above `errorDescription` in the alert.
    var alertTitle: String {
        switch self {
        case .emptyPhoneNumber: "no phone number"
        case .missingPlusPrefix: "incorrect formatting"
        case .emptyCode: "no code entered"
        case .missingVerificationID: "verification expired"
        case .emptyName: "no name provided"
        case .nameTooLong: "name is too long"
        case .reservedName: "invalid name"
        case .profanity: "ok, potty mouth"
        case .missingProfileDetails: "error creating account"
        case .timedOut, .underlying: "loading error"
        }
    }
}

// MARK: - Model

@Observable
@MainActor
final class OnboardingModel {
    // Entered by the person signing up.
    var phoneNumber = ""
    var verificationCode = ""
    var name = ""

    /// Set while a network call is in flight; drives the CTA's spinner.
    var isBusy = false
    /// Non-nil when an alert should be shown.
    var activeError: OnboardingError?

    /// Firebase's handle for the outstanding SMS. Memory-only by design.
    private var verificationID: String?

    private let database = DatabaseManager.shared
    private let profanity = ProfanityManager.shared

    /// Longest we'll wait on any single Firebase call before telling the user
    /// to check their connection.
    private static let requestTimeout: Duration = .seconds(20)

    // MARK: - Phone number step

    func sendVerificationCode() async throws {
        let entered = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard !entered.isEmpty else { throw OnboardingError.emptyPhoneNumber }
        guard entered.hasPrefix("+") else { throw OnboardingError.missingPlusPrefix }

        Auth.auth().languageCode = "en"
        SecureStorage.phoneNumber = entered

        let id = try await run {
            try await PhoneAuthProvider.provider().verifyPhoneNumber(entered, uiDelegate: nil)
        }
        verificationID = id
    }

    // MARK: - Verification step

    /// Signs in and reports whether this account still needs to pick a name.
    func verifyCode() async throws -> Bool {
        let code = verificationCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { throw OnboardingError.emptyCode }
        guard let verificationID else { throw OnboardingError.missingVerificationID }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )

        let signIn = try await run {
            let result = try await Auth.auth().signIn(with: credential)
            return (uid: result.user.uid, isNew: result.additionalUserInfo?.isNewUser == true)
        }

        SecureStorage.uid = signIn.uid
        if signIn.isNew { return true }

        // Returning user: pull their profile. If there's no document the account
        // exists in Auth but never finished onboarding, so send them through
        // the profile steps.
        guard let user = try? await database.downloadUser(
            where: FirestoreKeys.User.userIdentifier,
            isEqualTo: signIn.uid
        ) else {
            return true
        }

        cacheProfile(user)
        await hydrateAccount(uid: signIn.uid, profileImageURL: user.profileImageURL)

        // An existing account on a fresh install has never seen the system
        // prompt, so show it directly here. The in-app "can we annoy you" ask
        // isn't for these people — that one exists for someone who declined
        // during their original sign-up and never went back to fix it.
        //
        // Nothing appears for an account that already answered; this just
        // re-registers the device and refreshes the token.
        await PushManager.requestAuthorization(uid: signIn.uid)

        return false
    }

    /// Mirrors the returning-user profile into the values the rest of the app
    /// still reads out of UserDefaults.
    private func cacheProfile(_ user: User) {
        UserDefaults.standard.set(user.name, forKey: "name")
        UserDefaults.standard.set(user.status, forKey: "status")
        UserDefaults.standard.set(user.substatus, forKey: "substatus")
        UserDefaults.standard.set(user.profileImageURL, forKey: "profileImageURL")
        UserDefaults.standard.set(user.joinedTime, forKey: "joinedTime")
        UserDefaults.standard.set(user.explicit, forKey: "explicit")
        UserDefaults.standard.set(true, forKey: "loggedIn")
        // Deliberately not copying `user.fcmToken` into SecureStorage: it's
        // whatever install last wrote to this account, which on a reinstall or
        // a second device isn't this one. `PushManager` resolves the real one.
    }

    /// Warms everything the home screen expects to already be present. These
    /// run concurrently and none of them is allowed to block sign-in: a failed
    /// friends fetch shouldn't strand someone on the login screen.
    private func hydrateAccount(uid: String, profileImageURL: String) async {
        let database = self.database

        async let blocked: Void = {
            _ = await database.updateBlockedUsersList(uid: uid)
        }()

        async let friends: [String] = {
            do {
                return try await database.downloadAllFriends(uid: uid).map(\.uid)
            } catch {
                Log.database.error("onboarding — friends: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }()

        async let groups: [String] = {
            do {
                return try await database.downloadAllGroups(uid: uid).map(\.groupID)
            } catch {
                Log.database.error("onboarding — groups: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }()

        async let image: Void = Self.downloadProfileImage(uid: uid, profileImageURL: profileImageURL)

        let (_, friendUIDs, groupIDs, _) = await (blocked, friends, groups, image)

        if !friendUIDs.isEmpty {
            UserDefaults.standard.set(friendUIDs, forKey: "friendsUID")
        }
        if !groupIDs.isEmpty {
            UserDefaults.standard.set(groupIDs, forKey: "groupsUID")
        }
    }

    private static func downloadProfileImage(uid: String, profileImageURL: String) async {
        let placeholders = ["No profile picture yet", "No profile image yet", "no url", ""]
        guard !placeholders.contains(profileImageURL) else { return }

        let reference = Storage.storage().reference(withPath: "profile images/\(uid) - profile image.png")
        do {
            let data = try await reference.data(maxSize: 2 * 2048 * 2048)
            guard let image = UIImage(data: data) else { return }
            await MainActor.run {
                ImageStoreManager.shared.store(image: image, forKey: "profileImage")
            }
        } catch {
            Log.storage.error("onboarding — profile image: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Name step

    func validateAndStoreName() throws {
        let entered = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entered.isEmpty else { throw OnboardingError.emptyName }
        guard entered.count <= 16 else { throw OnboardingError.nameTooLong }
        // "user deleted" is the tombstone marker the backend writes, so it
        // can't be a real display name.
        guard entered != "user deleted" else { throw OnboardingError.reservedName }
        guard !profanity.checkForProfanity(in: entered) else { throw OnboardingError.profanity }

        name = entered
        UserDefaults.standard.set(entered, forKey: "name")
    }

    // MARK: - Finishing up

    /// Reports whether permission was granted, so the step can say which.
    ///
    /// No uid to pass: the user document doesn't exist until `createAccount`,
    /// so the token is resolved into SecureStorage for that to write.
    func requestNotificationPermission() async -> Bool {
        await PushManager.requestAuthorization(uid: nil)
    }

    func createAccount() async throws {
        let storedName = UserDefaults.standard.string(forKey: "name") ?? name
        guard !storedName.isEmpty,
              let phoneNumber = SecureStorage.phoneNumber,
              let uid = SecureStorage.uid
        else { throw OnboardingError.missingProfileDetails }

        let now = Date()
        let substatus = "find me something to do"
        let profileImageURL = UserDefaults.standard.string(forKey: "profileImageURL") ?? "No profile image yet"

        let newUser = User(
            name: storedName,
            phoneNumber: phoneNumber,
            uid: uid,
            fcmToken: SecureStorage.fcmToken ?? "Notifications not set up yet",
            status: "available",
            substatus: substatus,
            profileImageURL: profileImageURL,
            joinedTime: now.month + " " + now.year
        )

        let database = self.database
        try await run {
            try await database.createUser(newUser)
        }

        UserDefaults.standard.set(substatus, forKey: "substatus")
        UserDefaults.standard.set("available", forKey: "status")
        UserDefaults.standard.set(newUser.joinedTime, forKey: "joinedTime")
        UserDefaults.standard.set(profileImageURL, forKey: "profileImageURL")
        UserDefaults.standard.set(true, forKey: "loggedIn")

        // Normalises the token field now that there's a document to write to.
        // `newUser` above carried whatever SecureStorage had at the time, which
        // is nothing at all if the notification step was skipped — and the
        // placeholder it used instead isn't one the push fan-out knows to
        // ignore, so it would be handed to FCM as a real token.
        await PushManager.refreshRegistration(uid: uid)

        // Best-effort: a failed topic subscription shouldn't fail sign-up.
        do {
            try await Messaging.messaging().subscribe(toTopic: "All users")
        } catch {
            Log.push.error("onboarding — topic subscribe: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Plumbing

    /// Runs `work` with a spinner, a timeout, and uniform error translation.
    private func run<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        isBusy = true
        defer { isBusy = false }
        do {
            return try await withTimeout(Self.requestTimeout, operation: work)
        } catch is TimeoutError {
            throw OnboardingError.timedOut
        } catch let error as OnboardingError {
            throw error
        } catch {
            Log.auth.error("onboarding step failed: \(error.localizedDescription, privacy: .public)")
            throw OnboardingError.underlying(error.localizedDescription)
        }
    }
}

// MARK: - Timeout

struct TimeoutError: Error {}

/// Races `operation` against a sleep and cancels the loser. Replaces the
/// fire-and-forget `asyncAfter` timers the onboarding controllers used, which
/// kept running after the work had already finished.
func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimeoutError()
        }
        // First result wins; cancelling the group stops the other branch.
        guard let result = try await group.next() else { throw TimeoutError() }
        group.cancelAll()
        return result
    }
}
