//
//  TimeZone.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public extension TimeZone {
    static var currentFixed: TimeZone {
        TimeZone(secondsFromGMT: TimeZone.current.secondsFromGMT())!
    }
    
    static var utc: TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }
    
    /// This only works for fixed utc offset timezones
    func scheduleOffset(forDate date: Date) -> TimeInterval {
        var calendar = Calendar.current
        calendar.timeZone = self
        let components = calendar.dateComponents([.day , .month, .year], from: date)
        guard let startOfSchedule = calendar.date(from: components) else {
            fatalError("invalid date")
        }
        return date.timeIntervalSince(startOfSchedule)
    }

    var gattTimeZoneOffset: Int8 {
        // From GSSv6: The Time Zone characteristic is used to represent the time difference in 15-minute increments between local standard time and UTC.
        Int8(self.secondsFromGMT() / (60 * 15))
    }
}
