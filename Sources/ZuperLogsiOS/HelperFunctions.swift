//
//  File.swift
//  
//
//  Created by Jaikrishna on 23/01/24.
//

import Foundation

public let defaultLogServerDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

public func getUTCLogServerDateFormatString(date: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = defaultLogServerDateFormat
    if let convertedDate = formatter.date(from: date){
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: convertedDate)
    }
    return ""
}

public func getLogServerDateFormatString(date: Date) -> String? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = defaultLogServerDateFormat
    
    let dateString = dateFormatter.string(from: date)
    return dateString
}
