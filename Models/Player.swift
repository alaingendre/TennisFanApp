//
//  Player.swift
//  TennisFanApp
//
//  Created by Alain Gendre on 11/28/25.
//

import Foundation
import SwiftData

@Model
final class Player {
    var playerId: String
    var name: String
    var hand: String          // "R", "L", or "U"
    var countryCode: String   // 3-letter IOC code
    var height: Int?          // cm (from CSV or ATP_Database)
    var backhand: String?     // "1H" or "2H" (from ATP_Database)
    var birthdate: Date?      // from ATP_Database

    init(playerId: String, name: String, hand: String, countryCode: String,
         height: Int? = nil, backhand: String? = nil, birthdate: Date? = nil) {
        self.playerId = playerId
        self.name = name
        self.hand = hand
        self.countryCode = countryCode
        self.height = height
        self.backhand = backhand
        self.birthdate = birthdate
    }
}
