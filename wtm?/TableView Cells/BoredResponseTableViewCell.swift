//
//  BoredResponseTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/3/21.
//

import UIKit
import AnyFormatKit
import SDWebImage

class BoredResponseTableViewCell: UITableViewCell {
    static let identifier = "BoredResponseTableViewCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Bold", size: 24)
        label.textColor = UIColor(named: "darkBlueOnLight")
        label.numberOfLines = 1
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Thin", size: 12)
        label.textColor = UIColor(named: "secondaryLabelColors")
        label.numberOfLines = 2
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 10
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(statusImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(statusLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        statusImageView.frame = CGRect(x: 0, y: 15, width: 30, height: 30)
        
        let statusImageWidth = Int(statusImageView.frame.width)
        let offset = 10
        let contentViewWidth = Int(contentView.frame.width)
        nameLabel.frame = CGRect(x: statusImageWidth + offset, y: 5, width: contentViewWidth - statusImageWidth - offset, height: 35)
        statusLabel.frame = CGRect(x: statusImageView.frame.maxX + 10, y: nameLabel.frame.maxY - 5, width: CGFloat(contentViewWidth - statusImageWidth - offset), height: 20)
    }
    
    public func configure(with model: BoredRequestUser) {
        let blockedYou = ReportingManager.shared.userIsBlocked(theirUID: model.user.uid!)
        let blockedMe = ReportingManager.shared.userBlockedYou(theirUID: model.user.uid!)
        
        // Name label
        if model.user.uid == UserDefaults.standard.string(forKey: "uid") {
            nameLabel.text = "\(model.user.name!.lowercased()) (you)"
        } else {
            nameLabel.text = model.user.name!.lowercased()
        }
        
        // Status label
        if blockedMe || blockedYou {
            statusLabel.text = "blocked"
        } else {
            statusLabel.text = model.responseSubstatus
        }
        
        // Image View
        if blockedMe || blockedYou {
            statusImageView.image = UIImage(systemName: "hand.raised.slash")
            statusImageView.tintColor = .systemRed
        } else if model.responseStatus == "available" {
            statusImageView.image = UIImage(systemName: "checkmark.circle")
            statusImageView.tintColor = UIColor.systemGreen
        } else if model.responseStatus == "busy" {
            statusImageView.image = UIImage(systemName: "exclamationmark.circle")
            statusImageView.tintColor = UIColor(named: "darkYellowOnLight")
        } else if model.responseStatus == "not available" {
            statusImageView.image = UIImage(systemName: "nosign")
            statusImageView.tintColor = UIColor.systemRed
        } else {
            statusImageView.image = UIImage(systemName: "questionmark.circle")
            statusImageView.tintColor = UIColor.systemGray
        }
    }
}

