//
//  ImportedContactsTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import UIKit
import AnyFormatKit

class ImportedContactsTableViewCell: UITableViewCell {
    static let identifier = "ImportedContactsTableViewCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Bold", size: 18)
        label.textColor = UIColor(named: "darkBlueOnLight")
        label.numberOfLines = 0
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Thin", size: 12)
        label.textColor = UIColor(named: "secondaryLabelColors")
        label.numberOfLines = 0
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(nameLabel)
        contentView.addSubview(numberLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        nameLabel.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: 30)
        numberLabel.frame = CGRect(x: 0, y: nameLabel.frame.maxY, width: contentView.frame.width, height: 20)
    }
    
    public func configure(with model: PhoneContact) {
        nameLabel.text = model.name?.lowercased()
        
        guard model.phoneNumber.count != 0 else {
            numberLabel.text = "no number provided"
            return
        }
        
        numberLabel.text = model.phoneNumber[0]
        
        var formatter = DefaultTextFormatter(textPattern: "## (###) ###-####")
        
        if model.phoneNumber[0].count == 11 {
            formatter = DefaultTextFormatter(textPattern: "+# (###) ###-####")
            numberLabel.text = formatter.format(model.phoneNumber[0])
        } else if model.phoneNumber[0].count == 10 {
            formatter = DefaultTextFormatter(textPattern: "+1 (###) ###-####")
            numberLabel.text = formatter.format(model.phoneNumber[0])
        }
    }
}
