//
//  RequestsTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 6/2/21.
//

import UIKit
import AnyFormatKit

class RequestsTableViewCell: UITableViewCell {
    static let identifier = "RequestsTableViewCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Bold", size: 24)
        label.textColor = UIColor(named: "darkBlueOnLight")
        label.numberOfLines = 0
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(nameLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        nameLabel.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: 50)
    }
    
    public func configure(with model: FriendRequest) {
        nameLabel.text = model.name.lowercased()
    }
}
