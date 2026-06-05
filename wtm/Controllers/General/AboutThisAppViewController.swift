//
//  AboutThisAppViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import StoreKit

class AboutThisAppViewController: UIViewController, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
    let alertManager = AlertManager.shared
    var myProduct: SKProduct?

    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var supportLabel: UILabel!
    @IBOutlet weak var tipButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        reviewButton.layer.cornerRadius = 10
        tipButton.layer.cornerRadius = 10
        
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        fetchProducts()
    }

    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func tipButton(_ sender: Any) {
        guard let myProduct = myProduct else {
            return
        }
        
        if SKPaymentQueue.canMakePayments() {
            let payment = SKPayment(product: myProduct)
            SKPaymentQueue.default().add(self)
            SKPaymentQueue.default().add(payment)
        }
    }
    
    @IBAction func reviewButton(_ sender: Any) {
        let appleID = "1574130925"
        let url = "https://itunes.apple.com/app/id\(appleID)?action=write-review"
        if let path = URL(string: url) {
                UIApplication.shared.open(path, options: [:], completionHandler: nil)
        }
    }
    
    private func fetchProducts() {
        let request = SKProductsRequest(productIdentifiers: ["com.matthew.wtm.tipjar"])
        request.delegate = self
        request.start()
    }
    
    // MARK: - StoreKit Delegates
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if let product = response.products.first {
            myProduct = product
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                // no op
                break
            case .purchased, .restored:
                supportLabel.text = "you're pretty cool, believe it or not"
                supportLabel.textColor = .green
                SKPaymentQueue.default().finishTransaction(transaction)
                SKPaymentQueue.default().remove(self)
                break
            case .failed, .deferred:
                SKPaymentQueue.default().finishTransaction(transaction)
                SKPaymentQueue.default().remove(self)
                break
            default:
                SKPaymentQueue.default().finishTransaction(transaction)
                SKPaymentQueue.default().remove(self)
                break
            }
        }
    }
}

extension AboutThisAppViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
