//
//  BoredRequestTableViewCell.swift
//  wtm?
//
//  Created by Matthew McDonnell on 7/3/21.
//

import UIKit

class BoredRequestTableViewCell: UITableViewCell {
    static let identifier = "BoredRequestTableViewCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Bold", size: 30)
        label.textColor = .white
        label.numberOfLines = 1
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let activityLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Regular", size: 14)
        label.textColor = .white
        label.numberOfLines = 2
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private let expiringLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SuperBasic-Thin", size: 14)
        label.textColor = .white
        label.numberOfLines = 2
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0.4
        imageView.image = UIImage(named: "EmptyCircle")
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(backgroundImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(activityLabel)
        contentView.addSubview(expiringLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        backgroundImageView.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: contentView.frame.width)
        
        let padding = CGFloat(10)
        nameLabel.frame = CGRect(x: padding, y: 5, width: contentView.frame.width - padding, height: 60)
        activityLabel.frame = CGRect(x: padding, y: contentView.frame.height - 50, width: contentView.frame.width - padding, height: 30)
        expiringLabel.frame = CGRect(x: padding, y: contentView.frame.height - 30, width: contentView.frame.width - padding, height: 30)
    }
    
    public func configure(model: BoredRequest, group: FriendGroup) {
        nameLabel.text = group.name
        
        activityLabel.text = model.initiatedBy + " " + model.activity
        
        // Configure expiringLabel
        let expiringTime = model.expiresAt.toString(dateFormat: "h:mm a")
        expiringLabel.text = "expires at \(expiringTime)"
        
        // Configure backgroundImageView
        var image = UIImage(named: "chill")
        
        if model.activity == "wants to get coffee" {
            image = UIImage(named: "coffee")
        } else if model.activity == "is hungry" {
            image = UIImage(named: "food")
        } else if model.activity == "wants ice cream" {
            image = UIImage(named: "ice cream")
        } else if model.activity == "wants to go to the store" {
            image = UIImage(named: "store")
        } else if model.activity == "wants to go to the mall" {
            image = UIImage(named: "mall")
        } else if model.activity == "wants to go downtown" {
            image = UIImage(named: "city")
        } else if model.activity == "wants to go swimming" {
            image = UIImage(named: "swimming")
        } else if model.activity == "wants to go outside" {
            image = UIImage(named: "outdoors")
        } else if model.activity == "wants to play sports" {
            image = UIImage(named: "sports")
        } else if model.activity == "wants to workout" {
            image = UIImage(named: "workout")
        } else if model.activity == "wants to stare at you" {
            image = UIImage(named: "stare")
        } else if model.activity == "is bored" {
            image = UIImage(named: "idk")
        } else if model.activity == "wants to play with a dog" {
            image = UIImage(named: "dog")
        } else if model.activity == "wants to watch a movie" {
            image = UIImage(named: "movie")
        } else if model.activity == "wants to chill" {
            image = UIImage(named: "chill")
        } else if model.activity == "wants to drive around" {
            image = UIImage(named: "drive")
        } else if model.activity == "wants to sleep with you" {
            image = UIImage(named: "sleepover")
        } else if model.activity == "wants a kiss" {
            image = UIImage(named: "date night")
        }
        
        backgroundImageView.image = image
    }
}

