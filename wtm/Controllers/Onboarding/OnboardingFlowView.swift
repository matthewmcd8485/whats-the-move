//
//  OnboardingFlowView.swift
//  wtm?
//
//  The whole sign-up / sign-in flow as one SwiftUI island.
//
//  Previously this was five storyboard scenes pushed onto the app's shared
//  UINavigationController, each one instantiating the next by string identifier
//  and force-casting the result. Here the steps are a typed enum on a
//  NavigationStack path, so the order is declared in one place and a missing
//  step is a compile error rather than a runtime crash.
//
//  The seam with UIKit is a single point: LoadingViewController presents this,
//  and `onFinished` hands control back to push the tab bar.
//

import SwiftUI

// MARK: - Steps

enum OnboardingStep: Hashable {
    case phoneNumber
    case verification
    case name
    case finishingUp
}

// MARK: - Root

struct OnboardingFlowView: View {
    /// Called once the person is fully signed in and the home screen should
    /// take over.
    var onFinished: () -> Void = {}

    @State private var model = OnboardingModel()
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStep { path.append(.phoneNumber) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    destination(for: step)
                }
        }
        .environment(model)
        .tint(.wtmDarkBlue)
        // Every step draws its own heading, so the navigation bar would only
        // add an empty strip. The stack still provides the swipe-back gesture.
        .toolbar(.hidden, for: .navigationBar)
        .alert(
            model.activeError?.alertTitle ?? "something went wrong",
            isPresented: Binding(
                get: { model.activeError != nil },
                set: { if !$0 { model.activeError = nil } }
            )
        ) {
            Button("okay", role: .cancel) { model.activeError = nil }
        } message: {
            Text(model.activeError?.errorDescription ?? "")
        }
    }

    @ViewBuilder
    private func destination(for step: OnboardingStep) -> some View {
        switch step {
        case .phoneNumber:
            PhoneNumberStep { path.append(.verification) }
        case .verification:
            VerificationStep(
                onNeedsProfile: { path.append(.name) },
                onSignedIn: onFinished
            )
        case .name:
            NameStep { path.append(.finishingUp) }
        case .finishingUp:
            FinishingUpStep(onFinished: onFinished)
        }
    }
}

#Preview {
    OnboardingFlowView()
}
