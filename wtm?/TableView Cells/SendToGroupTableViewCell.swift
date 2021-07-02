//
//  SendToGroupTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/26/21.
//

import UIKit

class SendToGroupTableViewCell: UITableViewCell {
    static let identifier = "SendToGroupTableViewCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Bold", size: 24)
        label.textColor = UIColor(named: "darkBlueOnLight")
        label.numberOfLines = 1
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let peopleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Thin", size: 12)
        label.textColor = UIColor(named: "secondaryLabelColors")
        label.numberOfLines = 2
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        return label
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
        
        contentView.addSubview(nameLabel)
        contentView.addSubview(peopleLabel)
        contentView.addSubview(checkmarkImageView)
        contentView.addSubview(surfaceButton)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        checkmarkImageView.frame = CGRect(x: 0, y: 22, width: 30, height: 30)
        surfaceButton.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: contentView.frame.height)

        
        let padding = CGFloat(10)
        nameLabel.frame = CGRect(x: checkmarkImageView.frame.maxX + padding, y: 5, width: contentView.frame.width - checkmarkImageView.frame.width, height: 35)
        peopleLabel.frame = CGRect(x: checkmarkImageView.frame.maxX + padding, y: nameLabel.frame.maxY - 5, width: contentView.frame.width - checkmarkImageView.frame.width - padding, height: 40)
    }
    
    public func configure(with model: SelectableGroup) {
        nameLabel.text = model.group.name.lowercased()
        
        
        if let count = model.group.people?.count {
            if count == 1 {
                peopleLabel.text = "\(count) person"
            } else {
                peopleLabel.text = "\(count) people"
            }
        }
        
        if model.friends.count > 0 {
            let uid = UserDefaults.standard.string(forKey: "uid")
            var names = [String]()
            for x in model.friends.count {
                if model.friends[x].uid != uid {
                    names.append(model.friends[x].name.lowercased())
                }
            }
            peopleLabel.text = ListFormatter.localizedString(byJoining: names)
        }
    }
}
