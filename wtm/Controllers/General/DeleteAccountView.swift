//
//  DeleteAccountView.swift
//  wtm?
//

import SwiftUI
import FirebaseAuth

struct DeleteAccountView: View {
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var verificationID: String?
    @State private var verificationCode = ""
    @State private var showReauthAlert = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("backgroundColors").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("woah, dude!")
                    .font(.custom("SuperBasic-Bold", size: 48))
                    .foregroundStyle(Color("darkBlueOnLight"))

                Text("are you sure you want to do this? this is your last chance to turn back.")
                    .font(.custom("SuperBasic-Regular", size: 15))
                    .foregroundStyle(Color("secondaryLabelColors"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .symbolRenderingMode(.hierarchical)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .foregroundStyle(Color("darkRedOnLight"))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                if isWorking {
                    workingFooter
                } else {
                    buttonsFooter
                }
            }
            .padding(.horizontal, WTMLayout.sideMargin)
            .padding(.top, 8)
            .padding(.bottom, 20)

        }
        // The navigation bar's back button is hidden while the deletion is in
        // flight so the flow can't be abandoned midway through.
        .navigationBarBackButtonHidden(isWorking)
        .alert("check your messages", isPresented: $showReauthAlert) {
            TextField("ex. 123456", text: $verificationCode)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
            Button("cancel", role: .cancel) {
                verificationCode = ""
                isWorking = false
            }
            Button("continue") { continueReauthentication() }
        } message: {
            Text("you need to verify your identity before we can delete your account.\n\nenter the verification code we sent to the phone number associated with your account.")
        }
        .alert("error", isPresented: $showErrorAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "something went wrong.")
        }
    }

    private var workingFooter: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color("darkBlueOnLight"))
            Text("working...")
                .font(.custom("SuperBasic-Thin", size: 15))
                .foregroundStyle(Color("secondaryLabelColors"))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
    }

    private var buttonsFooter: some View {
        VStack(spacing: 16) {
            Button { dismiss() } label: {
                Text("oh my bad, cancel")
                    .font(.custom("SuperBasic-Bold", size: 20))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 61)
                    .background(Color("darkBlueOnLight"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: startDelete) {
                Text("i hate this dumb app, delete my account this instant")
                    .font(.custom("SuperBasic-Bold", size: 20))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .background(Color("darkRedOnLight"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func startDelete() {
        guard let phoneNumber = SecureStorage.phoneNumber else {
            errorMessage = "we couldn't find your phone number."
            showErrorAlert = true
            return
        }
        isWorking = true
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { id, error in
            DispatchQueue.main.async {
                if let error = error {
                    print(error.localizedDescription)
                    isWorking = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                    return
                }
                verificationID = id
                verificationCode = ""
                showReauthAlert = true
            }
        }
    }

    private func continueReauthentication() {
        guard let verificationID, !verificationCode.isEmpty else {
            isWorking = false
            return
        }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        Auth.auth().currentUser?.reauthenticate(with: credential) { _, error in
            if let error {
                print("Error reauthenticating user: \(error)")
                DispatchQueue.main.async {
                    isWorking = false
                    errorMessage = "verification failed. please try again."
                    showErrorAlert = true
                }
                return
            }
            removeFirestoreData()
        }
    }

    private func removeFirestoreData() {
        guard let uid = SecureStorage.uid else {
            fail("we couldn't find your account.", nil)
            return
        }

        // Each stage keeps its own message so the user is told what actually
        // failed, but the flow is now linear instead of three nested callbacks.
        Task { @MainActor in
            do {
                try await DatabaseManager.shared.softDeleteUserProfile(uid: uid)
            } catch {
                fail("we couldn't delete your profile. please try again.", error)
                return
            }

            do {
                try await DatabaseManager.shared.softDeleteFriendReferences(toUID: uid)
            } catch {
                fail("we couldn't fully clean up your data. please try again.", error)
                return
            }

            do {
                try await Auth.auth().currentUser?.delete()
                onDeleted()
            } catch {
                fail("we couldn't delete your account. please try again.", error)
            }
        }
    }

    private func fail(_ message: String, _ error: Error?) {
        if let error {
            Log.auth.error("Account deletion failed: \(error.localizedDescription, privacy: .public)")
        }
        isWorking = false
        errorMessage = message
        showErrorAlert = true
    }
}


#Preview {
    NavigationStack {
        DeleteAccountView()
    }
}
