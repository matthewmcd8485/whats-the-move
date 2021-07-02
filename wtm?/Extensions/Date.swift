//
//  Date.swift
//  wtm?
//
//  Created by Matthew McDonnell on 5/31/21.
//

import Foundation

extension Date {
    var month: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: self)
    }
    
    var year: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY"
        return dateFormatter.string(from: self)
    }
    
    func isInSameDayOf(date: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs:date)
    }
    
    func toString( dateFormat format  : String ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
