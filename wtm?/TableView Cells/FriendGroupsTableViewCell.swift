//
//  FriendGroupsTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/24/21.
//

import UIKit

class FriendGroupsTableViewCell: UITableViewCell {
    static let identifier = "FriendGroupsTableViewCell"
    
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
        label.numberOfLines = 1
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(nameLabel)
        contentView.addSubview(peopleLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        nameLabel.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: 30)
        peopleLabel.frame = CGRect(x: 0, y: nameLabel.frame.maxY, width: contentView.frame.width, height: 20)
    }
    
    public func configure(with group: FriendGroup) {
        nameLabel.text = group.name.lowercased()
        
        if let count = group.people?.count {
            if count == 1 {
                peopleLabel.text = "\(count) person"
            } else {
                peopleLabel.text = "\(count) people"
            }
        }
    }
}

