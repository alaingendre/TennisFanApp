//
//  DataLoader.swift
//  TennisFanApp
//
//  Created by Alain Gendre on 12/1/25.
//

import Foundation
import SwiftData

class DataLoader {
    
    // MARK: - CSV Parsing
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current)
        return columns
    }
    
    private static func toInt(_ s: String) -> Int? {
        Int(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private static func toDouble(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // MARK: - Name Matching
    //
    // Scraped names: "Rinderknech A.", "Fritz T.", "Carreno-Busta P."
    // Sackmann names: "Arthur Rinderknech", "Taylor Fritz", "Pablo Carreno Busta"
    //
    // Match by: last name + first initial
    
    private static func matchPlayerName(_ scrapedName: String, in playerDict: [String: Player]) -> String? {
        let trimmed = scrapedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If exact match exists, use it
        if playerDict[trimmed] != nil { return trimmed }
        
        let parts = trimmed.split(separator: " ").map(String.init)
        
        // Case 1: Single word name like "Medvedev", "Alcaraz", "Zverev"
        // Match to "Daniil Medvedev", "Carlos Alcaraz", "Alexander Zverev" by last name
        if parts.count == 1 {
            let lastName = trimmed.lowercased()
            var matches: [(name: String, player: Player)] = []
            for (fullName, player) in playerDict {
                let fullParts = fullName.split(separator: " ").map(String.init)
                guard fullParts.count >= 2 else { continue }
                let fullLastName = fullParts.dropFirst().joined(separator: " ").lowercased()
                if fullLastName == lastName {
                    matches.append((fullName, player))
                }
            }
            if matches.count == 1 { return matches[0].name }
            // Multiple matches: pick the one with the lowest (best) playerId number
            // or the most common one — heuristic: shorter playerId = more established player
            if matches.count > 1 {
                // Sort by playerId length (shorter = older/more established player ID)
                let sorted = matches.sorted { $0.player.playerId.count < $1.player.playerId.count }
                return sorted[0].name
            }
            return nil
        }
        
        // Case 2: "Lastname F." format with initial
        guard parts.count >= 2 else { return nil }
        
        let lastPart = parts.last!
        let isInitial = lastPart.count <= 2 || (lastPart.count == 2 && lastPart.hasSuffix("."))
        
        guard isInitial else { return nil }
        
        let initial = lastPart.prefix(1).uppercased()
        let lastName = parts.dropLast().joined(separator: " ")
        
        for (fullName, _) in playerDict {
            let fullParts = fullName.split(separator: " ").map(String.init)
            guard fullParts.count >= 2 else { continue }
            
            let fullFirstName = fullParts[0]
            let fullLastName = fullParts.dropFirst().joined(separator: " ")
            
            let lastNameNorm = lastName.lowercased().replacingOccurrences(of: "-", with: " ")
            let fullLastNameNorm = fullLastName.lowercased().replacingOccurrences(of: "-", with: " ")
            
            if lastNameNorm == fullLastNameNorm && fullFirstName.prefix(1).uppercased() == initial {
                return fullName
            }
        }
        
        return nil
    }
    
    // MARK: - Column Mapping
    //
    // 2024-2025: 50 columns (has "indoor" at 5, "winner_rank" at 16-17, "loser_rank" at 26-27)
    // 2020-2023: 49 columns (no "indoor", ranks at 45-48 at end)
    
    private struct Col {
        let tourneyId: Int
        let tourneyName: Int
        let surface: Int
        let drawSize: Int
        let tourneyLevel: Int
        let indoor: Int?          // nil for 2020-2023
        let tourneyDate: Int
        let matchNum: Int
        let winnerId: Int
        let winnerSeed: Int
        let winnerEntry: Int
        let winnerName: Int
        let winnerHand: Int
        let winnerHt: Int
        let winnerIoc: Int
        let winnerAge: Int
        let winnerRank: Int?      // nil if not available at this position
        let winnerRankPts: Int?
        let loserId: Int
        let loserSeed: Int
        let loserEntry: Int
        let loserName: Int
        let loserHand: Int
        let loserHt: Int
        let loserIoc: Int
        let loserAge: Int
        let loserRank: Int?
        let loserRankPts: Int?
        let score: Int
        let bestOf: Int
        let round: Int
        let minutes: Int
        let wAce: Int
        let wDf: Int
        let wSvpt: Int
        let w1stIn: Int
        let w1stWon: Int
        let w2ndWon: Int
        let wSvGms: Int
        let wBpSaved: Int
        let wBpFaced: Int
        let lAce: Int
        let lDf: Int
        let lSvpt: Int
        let l1stIn: Int
        let l1stWon: Int
        let l2ndWon: Int
        let lSvGms: Int
        let lBpSaved: Int
        let lBpFaced: Int
        // For 2020-2023, ranks are at end
        let winnerRankEnd: Int?
        let winnerRankPtsEnd: Int?
        let loserRankEnd: Int?
        let loserRankPtsEnd: Int?
        let minColumns: Int
    }
    
    private static func detectColumns(from header: String) -> Col {
        let cols = parseCSVLine(header)
        let hasIndoor = cols.contains("indoor")
        
        if hasIndoor {
            // 2024-2025 format (50 columns)
            return Col(
                tourneyId: 0, tourneyName: 1, surface: 2, drawSize: 3, tourneyLevel: 4,
                indoor: 5, tourneyDate: 6, matchNum: 7,
                winnerId: 8, winnerSeed: 9, winnerEntry: 10,
                winnerName: 11, winnerHand: 12, winnerHt: 13, winnerIoc: 14, winnerAge: 15,
                winnerRank: 16, winnerRankPts: 17,
                loserId: 18, loserSeed: 19, loserEntry: 20,
                loserName: 21, loserHand: 22, loserHt: 23, loserIoc: 24, loserAge: 25,
                loserRank: 26, loserRankPts: 27,
                score: 28, bestOf: 29, round: 30, minutes: 31,
                wAce: 32, wDf: 33, wSvpt: 34, w1stIn: 35, w1stWon: 36, w2ndWon: 37,
                wSvGms: 38, wBpSaved: 39, wBpFaced: 40,
                lAce: 41, lDf: 42, lSvpt: 43, l1stIn: 44, l1stWon: 45, l2ndWon: 46,
                lSvGms: 47, lBpSaved: 48, lBpFaced: 49,
                winnerRankEnd: nil, winnerRankPtsEnd: nil,
                loserRankEnd: nil, loserRankPtsEnd: nil,
                minColumns: 31
            )
        } else {
            // 2020-2023 format (49 columns, ranks at end)
            return Col(
                tourneyId: 0, tourneyName: 1, surface: 2, drawSize: 3, tourneyLevel: 4,
                indoor: nil, tourneyDate: 5, matchNum: 6,
                winnerId: 7, winnerSeed: 8, winnerEntry: 9,
                winnerName: 10, winnerHand: 11, winnerHt: 12, winnerIoc: 13, winnerAge: 14,
                winnerRank: nil, winnerRankPts: nil,
                loserId: 15, loserSeed: 16, loserEntry: 17,
                loserName: 18, loserHand: 19, loserHt: 20, loserIoc: 21, loserAge: 22,
                loserRank: nil, loserRankPts: nil,
                score: 23, bestOf: 24, round: 25, minutes: 26,
                wAce: 27, wDf: 28, wSvpt: 29, w1stIn: 30, w1stWon: 31, w2ndWon: 32,
                wSvGms: 33, wBpSaved: 34, wBpFaced: 35,
                lAce: 36, lDf: 37, lSvpt: 38, l1stIn: 39, l1stWon: 40, l2ndWon: 41,
                lSvGms: 42, lBpSaved: 43, lBpFaced: 44,
                winnerRankEnd: 45, winnerRankPtsEnd: 46,
                loserRankEnd: 47, loserRankPtsEnd: 48,
                minColumns: 26
            )
        }
    }
    
    // MARK: - ATP Database (player metadata)
    
    static func loadPlayerDatabasePublic() -> [String: (height: Int?, backhand: String?, birthdate: Date?)] {
        return loadPlayerDatabase()
    }
    
    static func loadSeasonPublic(from season: String, modelContext: ModelContext, playerDict: inout [String: Player], playerDB: [String: (height: Int?, backhand: String?, birthdate: Date?)]) {
        loadSeason(from: season, modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
    }
    
    static func load2026Public(modelContext: ModelContext, playerDict: inout [String: Player], playerDB: [String: (height: Int?, backhand: String?, birthdate: Date?)]) {
        load2026FromDocuments(modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
    }
    
    private static func loadPlayerDatabase() -> [String: (height: Int?, backhand: String?, birthdate: Date?)] {
        guard let url = Bundle.main.url(forResource: "ATP_Database", withExtension: "csv") else {
            return [:]
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        var db: [String: (height: Int?, backhand: String?, birthdate: Date?)] = [:]
        
        guard let content = try? String(contentsOf: url, encoding: .isoLatin1) else { return db }
        let lines = content.split(separator: "\n")
        
        // Header: "id","player","atpname","birthdate","weight","height","turnedpro","birthplace","coaches","hand","backhand","ioc"
        for (index, line) in lines.enumerated() {
            if index == 0 { continue }
            let col = parseCSVLine(String(line))
            guard col.count >= 12 else { continue }
            
            let playerId = col[0]
            let height = toInt(col[5])
            let backhand = col[10].isEmpty ? nil : col[10]
            let bdStr = col[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let birthdate = dateFormatter.date(from: bdStr)
            
            db[playerId] = (height, backhand, birthdate)
        }
        
        return db
    }
    
    // MARK: - Main Load
    
    static func loadData(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Player>()
            let existing = try modelContext.fetch(descriptor)
            if !existing.isEmpty {
                return
            }
        } catch {
            print("❌ Fetch error: \(error.localizedDescription)")
            return
        }
        
        // Load player metadata from ATP_Database.csv
        let playerDB = loadPlayerDatabase()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let bundledSeasons = ["2020", "2021", "2022", "2023", "2024", "2025"]
        var playerDict: [String: Player] = [:]
        
        for season in bundledSeasons {
            loadSeason(from: season, modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
        }
        
        // Load 2026 from Documents directory (seeded from embedded data, updated by scraper)
        load2026FromDocuments(modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Season Loading
    
    private static func loadSeason(from season: String, modelContext: ModelContext,
                                    playerDict: inout [String: Player],
                                    playerDB: [String: (height: Int?, backhand: String?, birthdate: Date?)]) {
        guard let url = Bundle.main.url(forResource: season, withExtension: "csv") else {
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        var gamesAdded = 0
        
        do {
            let content = try String(contentsOf: url, encoding: .isoLatin1)
            let lines = content.split(separator: "\n")
            guard lines.count > 1 else { return }
            
            let c = detectColumns(from: String(lines[0]))
            
            for (index, line) in lines.enumerated() {
                if index == 0 { continue }
                
                let col = parseCSVLine(String(line))
                guard col.count >= c.minColumns else { continue }
                
                let tourneyId = col[c.tourneyId]
                let matchNum = col[c.matchNum]
                let matchKey = "\(tourneyId)_\(matchNum)"
                
                let winnerName = col[c.winnerName]
                let loserName = col[c.loserName]
                guard !winnerName.isEmpty, !loserName.isEmpty else { continue }
                
                let tourneyDateStr = col[c.tourneyDate]
                guard let matchDate = dateFormatter.date(from: tourneyDateStr) else { continue }
                
                // --- Winner ---
                if playerDict[winnerName] == nil {
                    let pid = col[c.winnerId]
                    let meta = playerDB[pid]
                    let htFromCSV = toInt(col[c.winnerHt])
                    let p = Player(
                        playerId: pid,
                        name: winnerName,
                        hand: col[c.winnerHand].isEmpty ? "U" : col[c.winnerHand],
                        countryCode: col[c.winnerIoc].trimmingCharacters(in: .whitespacesAndNewlines),
                        height: meta?.height ?? htFromCSV,
                        backhand: meta?.backhand,
                        birthdate: meta?.birthdate
                    )
                    modelContext.insert(p)
                    playerDict[winnerName] = p
                }
                let winner = playerDict[winnerName]!
                
                // --- Loser ---
                if playerDict[loserName] == nil {
                    let pid = col[c.loserId]
                    let meta = playerDB[pid]
                    let htFromCSV = toInt(col[c.loserHt])
                    let p = Player(
                        playerId: pid,
                        name: loserName,
                        hand: col[c.loserHand].isEmpty ? "U" : col[c.loserHand],
                        countryCode: col[c.loserIoc].trimmingCharacters(in: .whitespacesAndNewlines),
                        height: meta?.height ?? htFromCSV,
                        backhand: meta?.backhand,
                        birthdate: meta?.birthdate
                    )
                    modelContext.insert(p)
                    playerDict[loserName] = p
                }
                let loser = playerDict[loserName]!
                
                // --- Rankings ---
                let winnerRank = c.winnerRank.flatMap { toInt(col[$0]) }
                    ?? c.winnerRankEnd.flatMap { col.count > $0 ? toInt(col[$0]) : nil }
                let loserRank = c.loserRank.flatMap { toInt(col[$0]) }
                    ?? c.loserRankEnd.flatMap { col.count > $0 ? toInt(col[$0]) : nil }
                
                // --- Stats (safe access) ---
                func stat(_ idx: Int) -> Int? {
                    col.count > idx ? toInt(col[idx]) : nil
                }
                
                let game = Game(
                    matchKey: matchKey,
                    tournamentName: col[c.tourneyName],
                    surface: col[c.surface],
                    tourneyLevel: col[c.tourneyLevel],
                    indoorOutdoor: c.indoor.map { col[$0] } ?? "",
                    drawSize: toInt(col[c.drawSize]) ?? 0,
                    round: col[c.round],
                    bestOf: toInt(col[c.bestOf]) ?? 3,
                    matchDate: matchDate,
                    score: col[c.score],
                    minutes: stat(c.minutes),
                    season: season,
                    winner: winner,
                    loser: loser,
                    winnerSeed: toInt(col[c.winnerSeed]),
                    winnerRank: winnerRank,
                    winnerAge: toDouble(col[c.winnerAge]),
                    loserSeed: toInt(col[c.loserSeed]),
                    loserRank: loserRank,
                    loserAge: toDouble(col[c.loserAge]),
                    wAce: stat(c.wAce), wDf: stat(c.wDf), wSvpt: stat(c.wSvpt),
                    w1stIn: stat(c.w1stIn), w1stWon: stat(c.w1stWon), w2ndWon: stat(c.w2ndWon),
                    wSvGms: stat(c.wSvGms), wBpSaved: stat(c.wBpSaved), wBpFaced: stat(c.wBpFaced),
                    lAce: stat(c.lAce), lDf: stat(c.lDf), lSvpt: stat(c.lSvpt),
                    l1stIn: stat(c.l1stIn), l1stWon: stat(c.l1stWon), l2ndWon: stat(c.l2ndWon),
                    lSvGms: stat(c.lSvGms), lBpSaved: stat(c.lBpSaved), lBpFaced: stat(c.lBpFaced)
                )
                modelContext.insert(game)
                gamesAdded += 1
            }
        } catch {
            print("❌ Failed to parse \(season).csv: \(error.localizedDescription)")
        }
        
    }
    
    // MARK: - 2026 from Documents Directory
    
    static func get2026URL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("2026.csv")
    }
    
    private static func load2026FromDocuments(modelContext: ModelContext,
                                               playerDict: inout [String: Player],
                                               playerDB: [String: (height: Int?, backhand: String?, birthdate: Date?)]) {
        let docsURL = get2026URL()
        
        // If no file in Documents yet, seed from embedded data
        if !FileManager.default.fileExists(atPath: docsURL.path) {
            seed2026FromEmbedded(to: docsURL)
        }
        
        guard FileManager.default.fileExists(atPath: docsURL.path) else {
            return
        }
        
        // Load using the same parser, but from Documents URL
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        var gamesAdded = 0
        
        do {
            let content = try String(contentsOf: docsURL, encoding: .utf8)
            let lines = content.split(separator: "\n")
            guard lines.count > 1 else {
                return
            }
            
            let c = detectColumns(from: String(lines[0]))
            
            for (index, line) in lines.enumerated() {
                if index == 0 { continue }
                
                let col = parseCSVLine(String(line))
                guard col.count >= c.minColumns else { continue }
                
                let tourneyId = col[c.tourneyId]
                let matchNum = col[c.matchNum]
                let matchKey = "\(tourneyId)_\(matchNum)"
                
                let rawWinnerName = col[c.winnerName]
                let rawLoserName = col[c.loserName]
                guard !rawWinnerName.isEmpty, !rawLoserName.isEmpty else { continue }
                
                // Match abbreviated scraped names to existing full names
                let winnerName = matchPlayerName(rawWinnerName, in: playerDict) ?? rawWinnerName
                let loserName = matchPlayerName(rawLoserName, in: playerDict) ?? rawLoserName
                
                let tourneyDateStr = col[c.tourneyDate]
                guard let matchDate = dateFormatter.date(from: tourneyDateStr) else { continue }
                
                // Winner
                if playerDict[winnerName] == nil {
                    let pid = col[c.winnerId]
                    let meta = playerDB[pid]
                    let htFromCSV = toInt(col[c.winnerHt])
                    let p = Player(
                        playerId: pid, name: winnerName,
                        hand: col[c.winnerHand].isEmpty ? "U" : col[c.winnerHand],
                        countryCode: col[c.winnerIoc].trimmingCharacters(in: .whitespacesAndNewlines),
                        height: meta?.height ?? htFromCSV, backhand: meta?.backhand, birthdate: meta?.birthdate
                    )
                    modelContext.insert(p)
                    playerDict[winnerName] = p
                }
                let winner = playerDict[winnerName]!
                
                // Loser
                if playerDict[loserName] == nil {
                    let pid = col[c.loserId]
                    let meta = playerDB[pid]
                    let htFromCSV = toInt(col[c.loserHt])
                    let p = Player(
                        playerId: pid, name: loserName,
                        hand: col[c.loserHand].isEmpty ? "U" : col[c.loserHand],
                        countryCode: col[c.loserIoc].trimmingCharacters(in: .whitespacesAndNewlines),
                        height: meta?.height ?? htFromCSV, backhand: meta?.backhand, birthdate: meta?.birthdate
                    )
                    modelContext.insert(p)
                    playerDict[loserName] = p
                }
                let loser = playerDict[loserName]!
                
                // Rankings
                let winnerRank = c.winnerRank.flatMap { toInt(col[$0]) }
                    ?? c.winnerRankEnd.flatMap { col.count > $0 ? toInt(col[$0]) : nil }
                let loserRank = c.loserRank.flatMap { toInt(col[$0]) }
                    ?? c.loserRankEnd.flatMap { col.count > $0 ? toInt(col[$0]) : nil }
                
                func stat(_ idx: Int) -> Int? { col.count > idx ? toInt(col[idx]) : nil }
                
                let game = Game(
                    matchKey: matchKey, tournamentName: col[c.tourneyName],
                    surface: col[c.surface], tourneyLevel: col[c.tourneyLevel],
                    indoorOutdoor: c.indoor.map { col[$0] } ?? "",
                    drawSize: toInt(col[c.drawSize]) ?? 0,
                    round: col[c.round], bestOf: toInt(col[c.bestOf]) ?? 3,
                    matchDate: matchDate, score: col[c.score], minutes: stat(c.minutes),
                    season: "2026", winner: winner, loser: loser,
                    winnerSeed: toInt(col[c.winnerSeed]), winnerRank: winnerRank,
                    winnerAge: toDouble(col[c.winnerAge]),
                    loserSeed: toInt(col[c.loserSeed]), loserRank: loserRank,
                    loserAge: toDouble(col[c.loserAge]),
                    wAce: stat(c.wAce), wDf: stat(c.wDf), wSvpt: stat(c.wSvpt),
                    w1stIn: stat(c.w1stIn), w1stWon: stat(c.w1stWon), w2ndWon: stat(c.w2ndWon),
                    wSvGms: stat(c.wSvGms), wBpSaved: stat(c.wBpSaved), wBpFaced: stat(c.wBpFaced),
                    lAce: stat(c.lAce), lDf: stat(c.lDf), lSvpt: stat(c.lSvpt),
                    l1stIn: stat(c.l1stIn), l1stWon: stat(c.l1stWon), l2ndWon: stat(c.l2ndWon),
                    lSvGms: stat(c.lSvGms), lBpSaved: stat(c.lBpSaved), lBpFaced: stat(c.lBpFaced)
                )
                modelContext.insert(game)
                gamesAdded += 1
            }
        } catch {
            print("  ❌ Failed to parse 2026.csv: \(error)")
        }
        
    }
    
    /// Copy 2026_seed.csv from bundle to Documents
    private static func seed2026FromEmbedded(to url: URL) {
        if let bundleURL = Bundle.main.url(forResource: "2026_seed", withExtension: "csv") {
            do {
                try FileManager.default.copyItem(at: bundleURL, to: url)
            } catch {
                print("  ❌ Failed to copy 2026_seed.csv: \(error)")
            }
        }
    }
}