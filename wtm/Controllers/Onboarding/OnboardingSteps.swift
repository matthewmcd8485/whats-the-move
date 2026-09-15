//
//  OnboardingSteps.swift
//  wtm?
//
//  The five onboarding screens, all built on `OnboardingScaffold`. Copy, fonts
//  and colours are carried over from the storyboard scenes they replace.
//

import SwiftUI

// MARK: - Welcome

struct WelcomeStep: View {
    let onContinue: () -> Void

    @State private var showTermsPrompt = false

    var body: some View {
        OnboardingScaffold(
            title: "wtm?",
            actionTitle: "get started",
            background: .wtmLightBlue,
            titleFont: .wtmHero,
            titleColor: .wtmDarkBlue,
            actionColor: .white
        ) {
            VStack(spacing: 4) {
                // The storyboard used a line separator inside one label; two
                // Text views read the same and wrap properly when scaled.
                Spacer()
                
                Text("solve your boredom.")
                Text("annoy your friends.")
            }
            .font(.wtmTagline)
            .foregroundStyle(.white)
            // The storyboard sat the taglines around the middle of the screen
            // rather than directly under the wordmark. Padding keeps that
            // breathing room without pinning them to an absolute y position.
            .padding(.top, 40)

            Text("all in one app.")
                .font(.wtmTaglineStrong)
                .foregroundStyle(Color.wtmDarkBlue)
        } action: {
            showTermsPrompt = true
        }
        .onAppear {
            // Preserves the default the rest of the app reads before a picture
            // has been chosen.
            if UserDefaults.standard.string(forKey: "profileImageURL") == nil {
                UserDefaults.standard.set("No profile image yet", forKey: "profileImageURL")
            }
        }
        .confirmationDialog(
            "agree before continuing",
            isPresented: $showTermsPrompt,
            titleVisibility: .visible
        ) {
            Button("i agree") { onContinue() }
            Button("privacy policy") {
                open("https://matthewdevteam.weebly.com/privacy.html")
            }
            Button("terms") {
                open("https://matthewdevteam.weebly.com/terms-and-conditions.html")
            }
            Button("i do not agree", role: .cancel) {}
        } message: {
            Text("by using this app, you agree to abide by the rules established in the privacy policy and terms & conditions.")
        }
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
        // Re-present so the person can still accept after reading.
        showTermsPrompt = true
    }
}

// MARK: - Phone number

struct PhoneNumberStep: View {
    let onContinue: () -> Void

    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model

        OnboardingScaffold(
            title: "enter your phone number",
            footnote: "a verification code will be sent to your device.\nstandard SMS messaging rates may apply.",
            actionTitle: "next",
            isBusy: model.isBusy
        ) {
            PhoneNumberFieldView(text: $model.phoneNumber, onSubmit: submit)
                .frame(height: 40)
                .onboardingField()
                .accessibilityLabel("phone number")
        } action: {
            submit()
        }
    }

    private func submit() {
        Task {
            do {
                try await model.sendVerificationCode()
                onContinue()
            } catch let error as OnboardingError {
                model.activeError = error
            } catch {
                model.activeError = .underlying(error.localizedDescription)
            }
        }
    }
}

// MARK: - Verification

struct VerificationStep: View {
    let onNeedsProfile: () -> Void
    let onSignedIn: () -> Void

    @Environment(OnboardingModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var model = model

        OnboardingScaffold(
            title: "check your\nmessages",
            subtitle: "enter the verification code that was just sent to your phone.",
            actionTitle: "log in",
            isBusy: model.isBusy
        ) {
            TextField("ex. 123456", text: $model.verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .onboardingField()
                .accessibilityLabel("verification code")
        } action: {
            submit()
        }
        .onAppear { isFocused = true }
    }

    private func submit() {
        Task {
            do {
                let needsProfile = try await model.verifyCode()
                if needsProfile {
                    onNeedsProfile()
                } else {
                    onSignedIn()
                }
            } catch let error as OnboardingError {
                model.activeError = error
            } catch {
                model.activeError = .underlying(error.localizedDescription)
            }
        }
    }
}

// MARK: - Name

struct NameStep: View {
    let onContinue: () -> Void

    @Environment(OnboardingModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var model = model

        OnboardingScaffold(
            title: "tell us\nabout yourself",
            subtitle: "we'll start with an easy one...\nwhat is your name?",
            footnote: "16 characters max.\nthis name can be changed later in settings.",
            actionTitle: "continue"
        ) {
            TextField("johnny appleseed", text: $model.name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.givenName)
                .focused($isFocused)
                .submitLabel(.continue)
                .onSubmit(submit)
                .onboardingField()
                .accessibilityLabel("your name")
        } action: {
            submit()
        }
        .onAppear { isFocused = true }
    }

    private func submit() {
        do {
            try model.validateAndStoreName()
            onContinue()
        } catch let error as OnboardingError {
            model.activeError = error
        } catch {
            model.activeError = .underlying(error.localizedDescription)
        }
    }
}

// MARK: - Finishing up

struct FinishingUpStep: View {
    let onFinished: () -> Void

    @Environment(OnboardingModel.self) private var model
    @State private var showPictureEditor = false
    /// `nil` until asked, then whether permission was granted. A refusal isn't
    /// the end of it — the app offers again later — but the step shouldn't
    /// claim notifications are on when they aren't.
    @State private var notificationsGranted: Bool?

    var body: some View {
        OnboardingScaffold(
            title: "some finishing\ntouches",
            actionTitle: "and that's it!",
            isBusy: model.isBusy
        ) {
            VStack(spacing: 24) {
                optionalStep(
                    title: "add a profile picture",
                    detail: "add a profile picture so we can all see how lame you look.",
                    isComplete: false
                ) {
                    showPictureEditor = true
                }

                optionalStep(
                    title: notificationsTitle,
                    detail: "enable notifications so your friends can annoy you when they're bored.",
                    isComplete: notificationsGranted == true,
                    // iOS won't show its prompt a second time, so tapping again
                    // after a refusal would do nothing at all.
                    isDisabled: notificationsGranted == false
                ) {
                    Task { notificationsGranted = await model.requestNotificationPermission() }
                }
            }
            .padding(.top, 8)
        } action: {
            finish()
        }
        .navigationDestination(isPresented: $showPictureEditor) {
            PictureEditView(onSaved: { showPictureEditor = false })
        }
    }

    private var notificationsTitle: String {
        switch notificationsGranted {
        case .some(true): "notifications enabled"
        case .some(false): "notifications are off"
        case .none: "enable notifications"
        }
    }

    @ViewBuilder
    private func optionalStep(
        title: String,
        detail: String,
        isComplete: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Text(title)
                    .font(.wtmActionSecondary)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.wtmDarkBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.wtmGroupedCard)
                    .clipShape(RoundedRectangle(cornerRadius: WTMLayout.cardCornerRadius))
                    // The tick sits in an overlay so it doesn't pull the
                    // centred title off-centre.
                    .overlay(alignment: .trailing) {
                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.wtmDarkBlue)
                                .padding(.trailing, 14)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isComplete || isDisabled)

            Text(detail)
                .font(.wtmSubtitle)
                .foregroundStyle(Color.wtmSecondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func finish() {
        Task {
            do {
                try await model.createAccount()
                onFinished()
            } catch let error as OnboardingError {
                model.activeError = error
            } catch {
                model.activeError = .underlying(error.localizedDescription)
            }
        }
    }
}


// MARK: - Previews

// The steps after Welcome read the model out of the environment, so previews
// have to supply one.
@MainActor
private func previewModel(busy: Bool = false) -> OnboardingModel {
    let model = OnboardingModel()
    model.isBusy = busy
    return model
}

#Preview("Welcome") {
    WelcomeStep {}
}

#Preview("Phone number") {
    PhoneNumberStep {}
        .environment(previewModel())
}

#Preview("Verification") {
    VerificationStep(onNeedsProfile: {}, onSignedIn: {})
        .environment(previewModel())
}

#Preview("Name") {
    NameStep {}
        .environment(previewModel())
}

#Preview("Finishing up") {
    NavigationStack {
        FinishingUpStep(onFinished: {})
            .environment(previewModel())
    }
}
