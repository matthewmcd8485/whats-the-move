//
//  AboutThisAppView.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/5/26.
//

import SwiftUI
import StoreKit

struct AboutThisAppView: View {
    private static let tipProductID = "com.matthew.wtm.tipjar"
    private static let appleID = "1574130925"

    var onBack: () -> Void = {}

    @State private var tipProduct: Product?
    @State private var didTip = false

    private var versionText: String {
        "app version \(UIApplication.appVersion()) (\(UIApplication.appBuild()))"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("lightBlueOnLight").ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("wtm?")
                        .font(.custom("SuperBasic-Bold", size: 100))
                        .foregroundStyle(Color("darkBlueOnLight"))
                    Text(versionText)
                        .font(.custom("SuperBasic-Regular", size: 15))
                        .foregroundStyle(Color("secondaryWhite"))
                }

                VStack(spacing: 8) {
                    Text("created with haste by matt")
                        .font(.custom("SuperBasic-Bold", size: 17))
                        .foregroundStyle(Color("secondaryWhite"))
                }

                Text("© 2026 matt mcdonnell.\nall rights reserved.")
                    .font(.custom("SuperBasic-Regular", size: 15))
                    .foregroundStyle(Color("secondaryWhite"))

                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    Text(didTip ? "you're pretty cool, believe it or not" : "help pay my rent")
                        .font(.custom("SuperBasic-Bold", size: 15))
                        .foregroundStyle(didTip ? Color.green : Color("secondaryWhite"))
                    Button(action: tipTapped) {
                        Text("tip jar")
                            .font(.custom("SuperBasic-Bold", size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 152, height: 61)
                            .background(Color("darkBlueOnLight"))
                    }
                }

                VStack(spacing: 6) {
                    Text("tell me how talented i am!")
                        .font(.custom("SuperBasic-Bold", size: 15))
                        .foregroundStyle(Color("secondaryWhite"))
                    Button(action: reviewTapped) {
                        Text("write a review")
                            .font(.custom("SuperBasic-Bold", size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 217, height: 61)
                            .background(Color("darkBlueOnLight"))
                    }
                }

                Text("fonts licensed from big cat creative")
                    .font(.custom("SuperBasic-Thin", size: 11))
                    .foregroundStyle(Color("secondaryWhite"))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color("secondaryWhite"))
                    .frame(width: 40, height: 40)
            }
            .padding(.leading, 16)
        }
        .navigationBarHidden(true)
        .task {
            await loadTipProduct()
        }
    }

    private func tipTapped() {
        guard let tipProduct, AppStore.canMakePayments else { return }
        Task { await purchase(tipProduct) }
    }

    private func reviewTapped() {
        guard let url = URL(string: "https://itunes.apple.com/app/id\(Self.appleID)?action=write-review") else { return }
        UIApplication.shared.open(url)
    }

    private func loadTipProduct() async {
        do {
            let products = try await Product.products(for: [Self.tipProductID])
            tipProduct = products.first
        } catch {
            print("Failed to load tip product: \(error)")
        }
    }

    @MainActor
    private func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    didTip = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
        }
    }
}

private final class AboutThisAppHostingController: UIHostingController<AboutThisAppView>, UIGestureRecognizerDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension AboutThisAppView {
    static func makeHostingController() -> UIViewController {
        let hc = AboutThisAppHostingController(rootView: AboutThisAppView())
        hc.rootView = AboutThisAppView(onBack: { [weak hc] in
            hc?.navigationController?.popViewController(animated: true)
        })
        return hc
    }
}
