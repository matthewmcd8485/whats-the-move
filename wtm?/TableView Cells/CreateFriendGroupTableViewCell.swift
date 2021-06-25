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
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        
        contentView.addSubview(statusImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(statusLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.accessoryType = selected ? .checkmark : .none
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        statusImageView.frame = CGRect(x: contentView.frame.width - 30, y: 10, width: 30, height: 30)
        
        let padding = CGFloat(10)
        nameLabel.frame = CGRect(x: padding, y: 0, width: contentView.frame.width - statusImageView.frame.width - padding, height: 30)
        statusLabel.frame = CGRect(x: padding, y: nameLabel.frame.maxY, width: contentView.frame.width - statusImageView.frame.width - padding, height: 20)
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
