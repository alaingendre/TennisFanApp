//
//  Game.swift
//  TennisFanApp
//
//  Created by Alain Gendre on 11/28/25.
//

import Foundation
import SwiftData

@Model
final class Game {
    // Identity
    var matchKey: String          // tourney_id + "_" + match_num
    
    // Tournament info
    var tournamentName: String
    var surface: String           // "Hard", "Clay", "Grass", "Carpet"
    var tourneyLevel: String      // "G"=Grand Slam, "M"=Masters, "A"=ATP500, "250", "D"=Davis Cup, "F"=Finals
    var indoorOutdoor: String     // "I" or "O" (2024+ only, "" for older)
    var drawSize: Int
    
    // Match info
    var round: String
    var bestOf: Int               // 3 or 5
    var matchDate: Date
    var score: String
    var minutes: Int?
    var season: String
    
    // Players
    var winner: Player
    var loser: Player
    
    // Rankings at time of match
    var winnerSeed: Int?
    var winnerRank: Int?
    var winnerAge: Double?
    var loserSeed: Int?
    var loserRank: Int?
    var loserAge: Double?
    
    // Winner match stats
    var wAce: Int?
    var wDf: Int?
    var wSvpt: Int?              // service points
    var w1stIn: Int?             // first serves in
    var w1stWon: Int?            // first serve points won
    var w2ndWon: Int?            // second serve points won
    var wSvGms: Int?             // service games
    var wBpSaved: Int?           // break points saved
    var wBpFaced: Int?           // break points faced
    
    // Loser match stats
    var lAce: Int?
    var lDf: Int?
    var lSvpt: Int?
    var l1stIn: Int?
    var l1stWon: Int?
    var l2ndWon: Int?
    var lSvGms: Int?
    var lBpSaved: Int?
    var lBpFaced: Int?

    init(matchKey: String, tournamentName: String, surface: String,
         tourneyLevel: String = "", indoorOutdoor: String = "", drawSize: Int = 0,
         round: String, bestOf: Int = 3, matchDate: Date, score: String,
         minutes: Int? = nil, season: String, winner: Player, loser: Player,
         winnerSeed: Int? = nil, winnerRank: Int? = nil, winnerAge: Double? = nil,
         loserSeed: Int? = nil, loserRank: Int? = nil, loserAge: Double? = nil,
         wAce: Int? = nil, wDf: Int? = nil, wSvpt: Int? = nil,
         w1stIn: Int? = nil, w1stWon: Int? = nil, w2ndWon: Int? = nil,
         wSvGms: Int? = nil, wBpSaved: Int? = nil, wBpFaced: Int? = nil,
         lAce: Int? = nil, lDf: Int? = nil, lSvpt: Int? = nil,
         l1stIn: Int? = nil, l1stWon: Int? = nil, l2ndWon: Int? = nil,
         lSvGms: Int? = nil, lBpSaved: Int? = nil, lBpFaced: Int? = nil) {
        self.matchKey = matchKey
        self.tournamentName = tournamentName
        self.surface = surface
        self.tourneyLevel = tourneyLevel
        self.indoorOutdoor = indoorOutdoor
        self.drawSize = drawSize
        self.round = round
        self.bestOf = bestOf
        self.matchDate = matchDate
        self.score = score
        self.minutes = minutes
        self.season = season
        self.winner = winner
        self.loser = loser
        self.winnerSeed = winnerSeed
        self.winnerRank = winnerRank
        self.winnerAge = winnerAge
        self.loserSeed = loserSeed
        self.loserRank = loserRank
        self.loserAge = loserAge
        self.wAce = wAce
        self.wDf = wDf
        self.wSvpt = wSvpt
        self.w1stIn = w1stIn
        self.w1stWon = w1stWon
        self.w2ndWon = w2ndWon
        self.wSvGms = wSvGms
        self.wBpSaved = wBpSaved
        self.wBpFaced = wBpFaced
        self.lAce = lAce
        self.lDf = lDf
        self.lSvpt = lSvpt
        self.l1stIn = l1stIn
        self.l1stWon = l1stWon
        self.l2ndWon = l2ndWon
        self.lSvGms = lSvGms
        self.lBpSaved = lBpSaved
        self.lBpFaced = lBpFaced
    }
}
