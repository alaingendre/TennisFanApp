//
//  Attendance.swift
//  TennisFanApp
//
//  Standalone attendance tracking that survives data reloads.
//  Keyed by matchKey (tourney_id + match_num) which is stable across reloads.
//

import Foundation
import SwiftData

@Model
final class Attendance {
    @Attribute(.unique) var matchKey: String  // e.g. "2025-580_1" (tourney_id + match_num)
    var attendedDate: Date
    
    init(matchKey: String, attendedDate: Date = Date()) {
        self.matchKey = matchKey
        self.attendedDate = attendedDate
    }
}
