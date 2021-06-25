//
//  MyProfileTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/30/21.
//

import UIKit
import Firebase

class MyProfileTableViewCell: UITableViewCell {
    static let identifier = "MyProfileTableViewCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Bold", size: 20)
        label.textColor = UIColor(named: "darkBlueOnLight")
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Thin", size: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.backgroundColor = UIColor(named: "secondaryBackgroundColors")!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        titleLabel.frame = CGRect(x: 10, y: 10, width: contentView.frame.width, height: 40)
        subtitleLabel.frame = CGRect(x: 10, y: titleLabel.frame.maxY - 10, width: contentView.frame.width, height: 30)
    }
    
    public func configure(with cell: MyProfileCell) {
        titleLabel.text = cell.title
        subtitleLabel.text = cell.subtitle
    }
}
