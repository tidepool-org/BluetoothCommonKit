//
//  Date.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

extension Date {
    // The GATT Date Time field is always in UTC, but a prototype may consider it a wall clock time
    func gattDateTime(using timeZone: TimeZone = TimeZone.utc) -> Data {
        var currentCalendar = Calendar.current
        currentCalendar.timeZone = timeZone
        var dateTime = Data(UInt16(currentCalendar.component(.year, from: self)))
        dateTime.append(UInt8(currentCalendar.component(.month, from: self)))
        dateTime.append(UInt8(currentCalendar.component(.day, from: self)))
        dateTime.append(UInt8(currentCalendar.component(.hour, from: self)))
        dateTime.append(UInt8(currentCalendar.component(.minute, from: self)))
        dateTime.append(UInt8(currentCalendar.component(.second, from: self)))
        return dateTime
    }

    // The GATT Date Time field is always in UTC, but a prototype may consider it a wall clock time
    init?(gattDateTime: Data, timeZone: TimeZone = TimeZone.utc) {
        guard gattDateTime.count == 7 else { return nil }

        let year = Int(gattDateTime[gattDateTime.startIndex...].to(UInt16.self))

        let month = Int(gattDateTime[gattDateTime.startIndex.advanced(by: 2)...].to(UInt8.self))
        guard month > 0 && month <= 12 else { return nil }

        let day = Int(gattDateTime[gattDateTime.startIndex.advanced(by: 3)...].to(UInt8.self))
        guard day > 0 && day <= 31 else { return nil }

        let hour = Int(gattDateTime[gattDateTime.startIndex.advanced(by: 4)...].to(UInt8.self))
        guard hour >= 0 && hour < 24 else { return nil }

        let minute = Int(gattDateTime[gattDateTime.startIndex.advanced(by: 5)...].to(UInt8.self))
        guard minute >= 0 && minute < 60 else { return nil }

        let second = Int(gattDateTime[gattDateTime.startIndex.advanced(by: 6)...].to(UInt8.self))
        guard second >= 0 && second < 60 else { return nil }

        var calendar = Calendar.current
        calendar.timeZone = timeZone

        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)) else { return nil }

        self = date
    }
}
