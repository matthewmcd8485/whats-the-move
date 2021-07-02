//
//  ActivityViewController.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/25/21.
//

import UIKit

class ActivityViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var moodLabel: UILabel!
    
    var pickerData: [String] = [String]()
    var collectionViewPickerData: [String] = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.interactivePopGestureRecognizer?.delegate = self

        collectionViewPickerData = PickerData.collectionViewData
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: (collectionView.frame.width / 2) - 6, height: (collectionView.frame.width / 2) - 6)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        collectionView.register(ActivityCollectionViewCell.self, forCellWithReuseIdentifier: ActivityCollectionViewCell.identifier)
        collectionView.dataSource = self
        collectionView.backgroundColor = UIColor(named: "backgroundColors")
        view.addSubview(collectionView)
        self.collectionView = collectionView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        collectionView?.frame = CGRect(x: 15, y: moodLabel.frame.maxY, width: view.frame.size.width - 30, height: view.frame.size.height - moodLabel.frame.maxY)
    }
    
    @IBAction func backButton(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - CollectionView Delegates
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionViewImages.count
    }

    
    let collectionViewImages = CategoryImages.categoryImages
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ActivityCollectionViewCell.identifier, for: indexPath) as? ActivityCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.layer.cornerRadius = 10
        cell.configure(with: collectionViewImages[indexPath.row]!, category: collectionViewPickerData[indexPath.row])
        cell.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapImage(_:))))
        return cell
    }
    
    @objc func tapImage(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: collectionView)
        let indexPath = collectionView?.indexPathForItem(at: location)
        
        print("tapped image: \(collectionViewPickerData[indexPath!.row])")
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "friendSelectionViewController") as FriendSelectionViewController
        vc.mood = NotificationTitle.init(integer: indexPath!.row)!
        navigationController?.pushViewController(vc, animated: true)
    }

}

extension ActivityViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
