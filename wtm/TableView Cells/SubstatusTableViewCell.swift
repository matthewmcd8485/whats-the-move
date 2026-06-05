//
//  SubstatusTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit

class SubstatusTableViewCell: UITableViewCell {
    static let identifier = "SubstatusTableViewCell"
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Regular", size: 18)
        label.textColor = UIColor(named: "darkBlueOnLight")
        label.numberOfLines = 2
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        label.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: 60)
    }
    
    public func configure(with substatus: String) {
        label.text = substatus
    }
}
