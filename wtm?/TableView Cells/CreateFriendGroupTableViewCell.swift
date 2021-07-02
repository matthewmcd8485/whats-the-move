//
//  CreateFriendGroupTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import UIKit

class CreateFriendGroupTableViewCell: UITableViewCell {
    static let identifier = "CreateFriendGroupTableViewCell"
    
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
    
    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "EmptyCircle")
        return imageView
    }()
    
    let surfaceButton: UIButton = {
        let button = UIButton()
        button.contentMode = .scaleAspectFit
        button.titleLabel?.text = ""
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(statusImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(checkmarkImageView)
        contentView.addSubview(surfaceButton)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        statusImageView.frame = CGRect(x: 0, y: 10, width: 30, height: 30)
        checkmarkImageView.frame = CGRect(x: contentView.frame.width - 30, y: 10, width: 30, height: 30)
        surfaceButton.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: contentView.frame.height)

        
        //let padding = CGFloat(10)
        nameLabel.frame = CGRect(x: statusImageView.frame.maxX + 10, y: 5, width: contentView.frame.width - statusImageView.frame.width - checkmarkImageView.frame.width, height: 30)
        statusLabel.frame = CGRect(x: statusImageView.frame.maxX + 10, y: nameLabel.frame.maxY, width: contentView.frame.width - statusImageView.frame.width - checkmarkImageView.frame.width, height: 20)
    }
    
    public func configure(with model: SelectableUser) {
        nameLabel.text = model.user.name!.lowercased()
        
        statusLabel.text = model.user.status!
        if model.user.status! == "available" {
            statusImageView.image = UIImage(systemName: "checkmark.seal")
            statusImageView.tintColor = UIColor.systemGreen
        } else if model.user.status! == "busy" {
            statusImageView.image = UIImage(systemName: "exclamationmark.bubble")
            statusImageView.tintColor = UIColor(named: "darkYellowOnLight")
        } else {
            statusImageView.image = UIImage(systemName: "nosign")
            statusImageView.tintColor = UIColor.systemRed
        }
    }
}
