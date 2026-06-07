//
//  DeleteAccountView.swift
//  wtm?
//

import SwiftUI
import FirebaseAuth

struct DeleteAccountView: View {
    var onBack: () -> Void = {}
    var onDeleted: () -> Void = {}

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
            .padding(.horizontal, 16)
            .padding(.top, 61)
            .padding(.bottom, 20)

            Button(action: backTapped) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .frame(width: 40, height: 40)
            }
            .padding(.leading, 16)
            .disabled(isWorking)
        }
        .navigationBarHidden(true)
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
            Button(action: backTapped) {
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

    private func backTapped() {
        guard !isWorking else { return }
        onBack()
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
            print("No UID found")
            DispatchQueue.main.async { isWorking = false }
            return
        }

        DatabaseManager.shared.softDeleteUserProfile(uid: uid) { result in
            if case .failure(let error) = result {
                print("Error deleting user's Firestore profile: \(error)")
                DispatchQueue.main.async {
                    isWorking = false
                    errorMessage = "we couldn't delete your profile. please try again."
                    showErrorAlert = true
                }
                return
            }
            print("Firestore profile cleared!")

            DatabaseManager.shared.softDeleteFriendReferences(toUID: uid) { result in
                if case .failure(let error) = result {
                    print("Error renaming friend references: \(error)")
                    DispatchQueue.main.async {
                        isWorking = false
                        errorMessage = "we couldn't fully clean up your data. please try again."
                        showErrorAlert = true
                    }
                    return
                }

                print("Data cleared!")
                Auth.auth().currentUser?.delete { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error deleting Auth user: \(error)")
                            isWorking = false
                            errorMessage = "we couldn't delete your account. please try again."
                            showErrorAlert = true
                        } else {
                            onDeleted()
                        }
                    }
                }
            }
        }
    }
}

private final class DeleteAccountHostingController: UIHostingController<DeleteAccountView>, UIGestureRecognizerDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension DeleteAccountView {
    static func makeHostingController() -> UIViewController {
        let hc = DeleteAccountHostingController(rootView: DeleteAccountView())
        hc.rootView = DeleteAccountView(
            onBack: { [weak hc] in
                hc?.navigationController?.popViewController(animated: true)
            },
            onDeleted: { [weak hc] in
                guard let hc else { return }
                hc.navigationController?.viewControllers = [hc]
                hc.tabBarController?.viewControllers = [hc]
                UserDefaults.resetDefaults()
                UserDefaults.standard.set(true, forKey: "launchedBefore")
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(identifier: "loadingViewController") as LoadingViewController
                hc.navigationController?.pushViewController(vc, animated: true)
            }
        )
        return hc
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
    }
}
