//
//  FriendsTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//

import UIKit
import AnyFormatKit
import SDWebImage

class FriendsTableViewCell: UITableViewCell {
    static let identifier = "FriendsTableViewCell"
    
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
        label.numberOfLines = 1
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
        
        statusImageView.frame = CGRect(x: 0, y: 10, width: 30, height: 30)
        
        let statusImageWidth = Int(statusImageView.frame.width)
        let offset = 10
        let contentViewWidth = Int(contentView.frame.width)
        nameLabel.frame = CGRect(x: statusImageWidth + offset, y: 0, width: contentViewWidth - statusImageWidth - offset, height: 30)
        statusLabel.frame = CGRect(x: statusImageView.frame.maxX + 10, y: nameLabel.frame.maxY, width: CGFloat(contentViewWidth - statusImageWidth - offset), height: 20)
    }
    
    public func configure(with model: User) {
        nameLabel.text = model.name!.lowercased()
        
        statusLabel.text = model.status!
        if model.status! == "available" {
            statusImageView.image = UIImage(systemName: "checkmark.seal")
            statusImageView.tintColor = UIColor.systemGreen
        } else if model.status! == "busy" {
            statusImageView.image = UIImage(systemName: "exclamationmark.bubble")
            statusImageView.tintColor = UIColor(named: "darkYellowOnLight")
        } else {
            statusImageView.image = UIImage(systemName: "nosign")
            statusImageView.tintColor = UIColor.systemRed
        }
    }
}

