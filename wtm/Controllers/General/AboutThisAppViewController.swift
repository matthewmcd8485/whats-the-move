//
//  AboutThisAppViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import StoreKit

class AboutThisAppViewController: UIViewController {
    
    private static let tipProductID = "com.matthew.wtm.tipjar"
    
    let alertManager = AlertManager.shared
    private var tipProduct: Product?

    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var supportLabel: UILabel!
    @IBOutlet weak var tipButton: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        reviewButton.layer.cornerRadius = 10
        tipButton.layer.cornerRadius = 10
        versionLabel.text = "app version \(UIApplication.appVersion()) (\(UIApplication.appBuild()))"
        
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        Task { await loadTipProduct() }
    }

    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func tipButton(_ sender: Any) {
        guard let tipProduct, AppStore.canMakePayments else { return }
        Task { await purchase(tipProduct) }
    }
    
    @IBAction func reviewButton(_ sender: Any) {
        let appleID = "1574130925"
        let url = "https://itunes.apple.com/app/id\(appleID)?action=write-review"
        if let path = URL(string: url) {
                UIApplication.shared.open(path, options: [:], completionHandler: nil)
        }
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
                    supportLabel.text = "you're pretty cool, believe it or not"
                    supportLabel.textColor = .green
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

extension AboutThisAppViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
