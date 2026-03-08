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
        
        // Case 1: Single word name like "Medvedev", "Alcaraz"
        // Match to "Daniil Medvedev", "Carlos Alcaraz" by last name
        if parts.count == 1 {
            let lastName = trimmed.lowercased()
            var matches: [String] = []
            for (fullName, _) in playerDict {
                let fullParts = fullName.split(separator: " ").map(String.init)
                guard fullParts.count >= 2 else { continue }
                let fullLastName = fullParts.dropFirst().joined(separator: " ").lowercased()
                if fullLastName == lastName {
                    matches.append(fullName)
                }
            }
            // Only return if exactly one match (avoid ambiguity)
            if matches.count == 1 { return matches[0] }
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
    
    private static func loadPlayerDatabase() -> [String: (height: Int?, backhand: String?, birthdate: Date?)] {
        guard let url = Bundle.main.url(forResource: "ATP_Database", withExtension: "csv") else {
            return [:]
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        
        var db: [String: (height: Int?, backhand: String?, birthdate: Date?)] = [:]
        
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return db }
        let lines = content.split(separator: "\n")
        
        // Header: "id","player","atpname","birthdate","weight","height","turnedpro","birthplace","coaches","hand","backhand","ioc"
        for (index, line) in lines.enumerated() {
            if index == 0 { continue }
            let col = parseCSVLine(String(line))
            guard col.count >= 12 else { continue }
            
            let playerId = col[0]
            let height = toInt(col[5])
            let backhand = col[10].isEmpty ? nil : col[10]
            let birthdate = dateFormatter.date(from: col[3])
            
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
    
    /// Write 2026 CSV data directly to Documents (bypasses Xcode bundle issues)
    private static func seed2026FromEmbedded(to url: URL) {
        let csvData = """
tourney_id,tourney_name,surface,draw_size,tourney_level,indoor,tourney_date,match_num,winner_id,winner_seed,winner_entry,winner_name,winner_hand,winner_ht,winner_ioc,winner_age,winner_rank,winner_rank_points,loser_id,loser_seed,loser_entry,loser_name,loser_hand,loser_ht,loser_ioc,loser_age,loser_rank,loser_rank_points,score,best_of,round,minutes,w_ace,w_df,w_svpt,w_1stIn,w_1stWon,w_2ndWon,w_SvGms,w_bpSaved,w_bpFaced,l_ace,l_df,l_svpt,l_1stIn,l_1stWon,l_2ndWon,l_SvGms,l_bpSaved,l_bpFaced
2026-united-cup,United Cup,Hard,,D,,20260111,1,hurkacz,,,Hurkacz,,,,,,,wawrinka-ffdb9,,,Wawrinka,,,,,,,6-3 3-6 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260110,2,hurkacz,,,Hurkacz,,,,,,,fritz-f1aa7,,,Fritz,,,,,,,7-61 7-62,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260110,3,bergs,,,Bergs,,,,,,,wawrinka-ffdb9,,,Wawrinka,,,,,,,6-3 64-7 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260109,4,de-minaur,,,De Minaur,,,,,,,hurkacz,,,Hurkacz,,,,,,,6-4 4-6 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260108,5,bergs,,,Bergs,,,,,,,mensik,,,Mensik,,,,,,,6-2 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260107,6,baez-a8fb1,,,Baez,,,,,,,wawrinka-ffdb9,,,Wawrinka,,,,,,,7-5 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260107,7,tsitsipas-b526f,,,Tsitsipas,,,,,,,fritz-f1aa7,,,Fritz,,,,,,,6-4 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260107,8,hurkacz,,,Hurkacz,,,,,,,griekspoor-d58ed,,,Griekspoor,,,,,,,6-3 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260106,9,de-minaur,,,De Minaur,,,,,,,mensik,,,Mensik,,,,,,,6-4 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260106,10,rinderknech,,,Rinderknech,,,,,,,cobolli-d6311,,,Cobolli,,,,,,,64-7 7-65 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260106,11,bergs,,,Bergs,,,,,,,auger-aliassime,,,Auger Aliassime,,,,,,,6-4 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260105,12,tsitsipas-b526f,,,Tsitsipas,,,,,,,harris-5a94c,,,Harris,,,,,,,4-6 6-1 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260105,13,hurkacz,,,Hurkacz,,,,,,,zverev-6f768,,,Zverev,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260105,14,fritz-f1aa7,,,Fritz,,,,,,,munar-d1298,,,Munar,,,,,,,7-64 3-6 7-66,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260105,15,mensik,,,Mensik,,,,,,,ruud-dfb38,,,Ruud,,,,,,,7-5 7-66,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260104,16,cobolli-d6311,,,Cobolli,,,,,,,wawrinka-ffdb9,,,Wawrinka,,,,,,,6-4 62-7 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260104,17,auger-aliassime,,,Auger Aliassime,,,,,,,zhang-45ae9,,,Zhang,,,,,,,6-4 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260104,18,harris-5a94c,,,Harris,,,,,,,mochizuki-f2487,,,Mochizuki,,,,,,,7-64 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260104,19,zverev-6f768,,,Zverev,,,,,,,griekspoor-d58ed,,,Griekspoor,,,,,,,7-5 6-0,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260103,20,baez-a8fb1,,,Baez,,,,,,,fritz-f1aa7,,,Fritz,,,,,,,4-6 7-5 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260103,21,ruud-dfb38,,,Ruud,,,,,,,de-minaur,,,De Minaur,,,,,,,6-3 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260103,22,wawrinka-ffdb9,,,Wawrinka,,,,,,,rinderknech,,,Rinderknech,,,,,,,5-7 7-65 7-65,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260103,23,zhang-45ae9,,,Zhang,,,,,,,bergs,,,Bergs,,,,,,,62-7 7-63 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260102,24,tsitsipas-b526f,,,Tsitsipas,,,,,,,mochizuki-f2487,,,Mochizuki,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260102,25,baez-a8fb1,,,Baez,,,,,,,munar-d1298,,,Munar,,,,,,,6-4 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260111,1,bublik-43f80,2,,Bublik,,,,,,,musetti,1,,Musetti,,,,,,,7-62 6-3,3,F,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260110,2,bublik-43f80,2,,Bublik,,,,,,,giron-49e97,,,Giron,,,,,,,3-6 6-4 6-2,3,SF,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260110,3,musetti,1,,Musetti,,,,,,,rublev,3,,Rublev,,,,,,,63-7 7-5 6-4,3,SF,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260109,4,giron-49e97,,,Giron,,,,,,,mmoh,,,Mmoh,,,,,,,6-3 1-0,3,QF,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260109,5,bublik-43f80,2,,Bublik,,,,,,,shang,,,Shang,,,,,,,6-1 7-62,3,QF,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260109,6,rublev,3,,Rublev,,,,,,,borges-8d823,8,,Borges,,,,,,,6-3 6-4,3,QF,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260109,7,musetti,1,,Musetti,,,,,,,wong-d3ead,,,Wong,,,,,,,6-4 6-4,3,QF,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260108,8,bublik-43f80,2,,Bublik,,,,,,,van-de-zandschulp,,,Van De Zandschulp,,,,,,,6-3 6-3,3,R16,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260108,9,mmoh,,,Mmoh,,,,,,,khachanov,4,,Khachanov,,,,,,,7-62 7-64,3,R16,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260108,10,giron-49e97,,,Giron,,,,,,,muller-c81bc,7,,Muller,,,,,,,6-4 7-64,3,R16,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260108,11,shang,,,Shang,,,,,,,sonego,5,,Sonego,,,,,,,6-3 6-4,3,R16,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260107,12,rublev,3,,Rublev,,,,,,,wu-9762d,,,Wu,,,,,,,3-6 6-2 6-1,3,R16,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260107,13,wong-d3ead,,,Wong,,,,,,,diallo-dd116,6,,Diallo,,,,,,,1-6 7-5 7-5,3,R16,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260107,14,borges-8d823,8,,Borges,,,,,,,cilic,,,Cilic,,,,,,,7-5 6-3,3,R16,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260107,15,musetti,1,,Musetti,,,,,,,etcheverry-7101a,,,Etcheverry,,,,,,,63-7 6-2 6-4,3,R16,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,16,shang,,,Shang,,,,,,,comesana-c17e0,,,Comesana,,,,,,,6-4 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,17,giron-49e97,,,Giron,,,,,,,djere,,,Djere,,,,,,,6-2 6-0,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,18,van-de-zandschulp,,,Van De Zandschulp,,,,,,,struff,,,Struff,,,,,,,6-3 1-6 6-1,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,19,mmoh,,,Mmoh,,,,,,,tabilo,,,Tabilo,,,,,,,7-5 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,20,diallo-dd116,6,,Diallo,,,,,,,de-jong-57322,,,De Jong,,,,,,,6-4 7-67,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,21,wong-d3ead,,,Wong,,,,,,,navone,,,Navone,,,,,,,6-3 7-5,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,22,etcheverry-7101a,,,Etcheverry,,,,,,,royer,,,Royer,,,,,,,6-4 7-5,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,23,muller-c81bc,7,,Muller,,,,,,,kecmanovic,,,Kecmanovic,,,,,,,7-5 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260106,24,sonego,5,,Sonego,,,,,,,sakamoto-9c9d5,,,Sakamoto,,,,,,,6-2 7-64,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260105,25,wu-9762d,,,Wu,,,,,,,marozsan,,,Marozsan,,,,,,,6-4 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260105,26,cilic,,,Cilic,,,,,,,mannarino-a7108,,,Mannarino,,,,,,,6-3 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-hong-kong-atp,Hong Kong ATP,Hard,,250,,20260105,27,borges-8d823,8,,Borges,,,,,,,dzumhur,,,Dzumhur,,,,,,,6-4 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260111,1,medvedev-e0d2d,1,,Medvedev,,,,,,,nakashima-68876,,,Nakashima,,,,,,,6-2 7-61,3,F,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260110,2,medvedev-e0d2d,1,,Medvedev,,,,,,,michelsen-a98bb,,,Michelsen,,,,,,,6-4 6-2,3,SF,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260110,3,nakashima-68876,,,Nakashima,,,,,,,kovacevic-a2706,,,Kovacevic,,,,,,,7-64 6-4,3,SF,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260109,4,medvedev-e0d2d,1,,Medvedev,,,,,,,majchrzak-905d8,,,Majchrzak,,,,,,,64-7 6-3 6-2,3,QF,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260109,5,michelsen-a98bb,,,Michelsen,,,,,,,korda-2529f,,,Korda,,,,,,,6-3 7-67,3,QF,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260109,6,nakashima-68876,,,Nakashima,,,,,,,collignon,,,Collignon,,,,,,,6-3 6-3,3,QF,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260109,7,kovacevic-a2706,,,Kovacevic,,,,,,,mpetshi-perricard,,,Mpetshi Perricard,,,,,,,7-63 4-6 6-3,3,QF,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260108,8,collignon,,,Collignon,,,,,,,dimitrov-779bc,,,Dimitrov,,,,,,,7-61 6-3,3,R16,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260108,9,mpetshi-perricard,,,Mpetshi Perricard,,,,,,,hijikata,,,Hijikata,,,,,,,4-6 7-65 7-64,3,R16,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260108,10,nakashima-68876,,,Nakashima,,,,,,,halys,,,Halys,,,,,,,6-2 6-4,3,R16,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260108,11,kovacevic-a2706,,,Kovacevic,,,,,,,norrie,7,,Norrie,,,,,,,7-64 4-6 6-4,3,R16,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260107,12,majchrzak-905d8,,,Majchrzak,,,,,,,opelka,,,Opelka,,,,,,,62-7 7-67 7-68,3,R16,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260107,13,korda-2529f,,,Korda,,,,,,,lehecka,3,,Lehecka,,,,,,,6-3 1-2,3,R16,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260107,14,medvedev-e0d2d,1,,Medvedev,,,,,,,tiafoe,,,Tiafoe,,,,,,,6-3 6-2,3,R16,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260107,15,michelsen-a98bb,,,Michelsen,,,,,,,tien,8,,Tien,,,,,,,6-4 6-2,3,R16,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260106,16,dimitrov-779bc,,,Dimitrov,,,,,,,carreno-busta,,,Carreno-Busta,,,,,,,6-3 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260106,17,hijikata,,,Hijikata,,,,,,,walton,,,Walton,,,,,,,6-3 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260106,18,norrie,7,,Norrie,,,,,,,humbert-e2553,,,Humbert,,,,,,,1-6 7-66 7-5,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260106,19,kovacevic-a2706,,,Kovacevic,,,,,,,kyrgios,,,Kyrgios,,,,,,,6-3 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260106,20,mpetshi-perricard,,,Mpetshi Perricard,,,,,,,paul-324c3,4,,Paul,,,,,,,7-62 3-6 7-66,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260106,21,nakashima-68876,,,Nakashima,,,,,,,davidovich-fokina,2,,Davidovich Fokina,,,,,,,7-64 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260106,22,collignon,,,Collignon,,,,,,,shapovalov,5,,Shapovalov,,,,,,,6-4 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260105,23,medvedev-e0d2d,1,,Medvedev,,,,,,,fucsovics,,,Fucsovics,,,,,,,6-2 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260105,24,opelka,,,Opelka,,,,,,,sweeny,,,Sweeny,,,,,,,6-3 7-5,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260105,25,halys,,,Halys,,,,,,,popyrin,,,Popyrin,,,,,,,5-7 6-3 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260105,26,majchrzak-905d8,,,Majchrzak,,,,,,,altmaier,,,Altmaier,,,,,,,7-64 6-0,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260105,27,lehecka,3,,Lehecka,,,,,,,machac,,,Machac,,,,,,,6-4 65-7 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260105,28,michelsen-a98bb,,,Michelsen,,,,,,,duckworth,,,Duckworth,,,,,,,64-7 7-62 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260105,29,korda-2529f,,,Korda,,,,,,,vacherot,,,Vacherot,,,,,,,7-61 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260104,30,tien,8,,Tien,,,,,,,ugo-carabelli,,,Ugo Carabelli,,,,,,,7-64 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260104,31,tiafoe,,,Tiafoe,,,,,,,vukic,,,Vukic,,,,,,,6-2 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260305,1,fonseca-57dc1,,,Fonseca,,,,,,,collignon,,,Collignon,,,,,,,7-62 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260305,2,svajda,,,Svajda,,,,,,,cilic,,,Cilic,,,,,,,7-65 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260305,3,monfils,,,Monfils,,,,,,,galarneau-32e1f,,,Galarneau,,,,,,,6-3 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260305,4,brooksby,,,Brooksby,,,,,,,popyrin,,,Popyrin,,,,,,,6-3 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260305,5,prizmic,,,Prizmic,,,,,,,schoolkate,,,Schoolkate,,,,,,,7-65 3-6 7-5,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260305,6,berrettini-707ad,,,Berrettini,,,,,,,mannarino-a7108,,,Mannarino,,,,,,,4-6 7-5 7-5,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,7,fucsovics,,,Fucsovics,,,,,,,o-connell-020b8,,,O'Connell,,,,,,,7-5 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,8,svrcina,,,Svrcina,,,,,,,duckworth,,,Duckworth,,,,,,,6-2 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,9,diallo-dd116,,,Diallo,,,,,,,bellucci-47e7e,,,Bellucci,,,,,,,7-65 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,10,opelka,,,Opelka,,,,,,,quinn-d0193,,,Quinn,,,,,,,7-5 7-63,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,11,bergs,,,Bergs,,,,,,,struff,,,Struff,,,,,,,6-3 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,12,kecmanovic,,,Kecmanovic,,,,,,,altmaier,,,Altmaier,,,,,,,6-3 1-0,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,13,ugo-carabelli,,,Ugo Carabelli,,,,,,,damm-4f98a,,,Damm,,,,,,,7-65 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,14,walton,,,Walton,,,,,,,halys,,,Halys,,,,,,,6-3 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260304,15,giron-49e97,,,Giron,,,,,,,navone,,,Navone,,,,,,,4-6 7-5 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260208,1,auger-aliassime,1,,Auger Aliassime,,,,,,,mannarino-a7108,,,Mannarino,,,,,,,6-3 7-64,3,F,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260207,2,auger-aliassime,1,,Auger Aliassime,,,,,,,droguet,,,Droguet,,,,,,,6-4 65-7 6-1,3,SF,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260207,3,mannarino-a7108,,,Mannarino,,,,,,,damm-4f98a,,,Damm,,,,,,,1-6 6-3 6-4,3,SF,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260206,4,droguet,,,Droguet,,,,,,,griekspoor-d58ed,4,,Griekspoor,,,,,,,7-65 7-61,3,QF,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260206,5,auger-aliassime,1,,Auger Aliassime,,,,,,,fils,6,,Fils,,,,,,,6-4 6-2,3,QF,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260206,6,damm-4f98a,,,Damm,,,,,,,nardi-e2cda,,,Nardi,,,,,,,6-3 7-68,3,QF,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260206,7,mannarino-a7108,,,Mannarino,,,,,,,gea,,,Gea,,,,,,,5-7 6-4 6-4,3,QF,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260205,8,fils,6,,Fils,,,,,,,blanchet,,,Blanchet,,,,,,,7-64 7-5,3,R16,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260205,9,auger-aliassime,1,,Auger Aliassime,,,,,,,wawrinka-ffdb9,,,Wawrinka,,,,,,,6-4 7-63,3,R16,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260205,10,nardi-e2cda,,,Nardi,,,,,,,cobolli-d6311,2,,Cobolli,,,,,,,6-2 6-3,3,R16,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260205,11,griekspoor-d58ed,4,,Griekspoor,,,,,,,carreno-busta,,,Carreno-Busta,,,,,,,6-4 6-4,3,R16,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260205,12,droguet,,,Droguet,,,,,,,kovacevic-a2706,8,,Kovacevic,,,,,,,4-6 7-65 6-4,3,R16,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260204,13,gea,,,Gea,,,,,,,machac,3,,Machac,,,,,,,6-3 4-5,3,R16,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260204,14,mannarino-a7108,,,Mannarino,,,,,,,humbert-e2553,5,,Humbert,,,,,,,64-7 6-3 7-64,3,R16,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260204,15,damm-4f98a,,,Damm,,,,,,,bautista-agut,,,Bautista-Agut,,,,,,,6-1 6-3,3,R16,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260204,16,wawrinka-ffdb9,,,Wawrinka,,,,,,,medjedovic,,,Medjedovic,,,,,,,7-63 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260204,17,kovacevic-a2706,8,,Kovacevic,,,,,,,kouame-d4969,,,Kouame,,,,,,,65-7 6-2 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260204,18,nardi-e2cda,,,Nardi,,,,,,,basilashvili,,,Basilashvili,,,,,,,6-3 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260203,19,blanchet,,,Blanchet,,,,,,,vavassori,,,Vavassori,,,,,,,6-4 6-3,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260203,20,fils,6,,Fils,,,,,,,royer,,,Royer,,,,,,,7-67 64-7 6-2,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260203,21,humbert-e2553,5,,Humbert,,,,,,,van-de-zandschulp,,,Van De Zandschulp,,,,,,,6-3 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260203,22,droguet,,,Droguet,,,,,,,choinski,,,Choinski,,,,,,,6-2 7-62,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260203,23,damm-4f98a,,,Damm,,,,,,,hurkacz,7,,Hurkacz,,,,,,,7-65 6-4,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260203,24,carreno-busta,,,Carreno-Busta,,,,,,,kecmanovic,,,Kecmanovic,,,,,,,4-6 6-3 7-64,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260202,25,bautista-agut,,,Bautista-Agut,,,,,,,o-connell-020b8,,,O'Connell,,,,,,,5-7 6-3 7-5,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260202,26,gea,,,Gea,,,,,,,mpetshi-perricard,,,Mpetshi Perricard,,,,,,,6-3 0-0,3,R128,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260202,27,mannarino-a7108,,,Mannarino,,,,,,,martinez-c0caf,,,Martinez,,,,,,,7-63 6-1,3,R128,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,1,dellien-e101c,,,Dellien,,,,,,,marshall-0d239,,,Marshall,,,,,,,7-64 7-66,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,2,kubler-21879,,,Kubler,,,,,,,camacho-47a51,,,Camacho,,,,,,,6-4 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,3,roncadelli,,,Roncadelli,,,,,,,bicknell-8dc8a,,,Bicknell,,,,,,,6-3 5-7 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,4,king-01912,,,King,,,,,,,prado-angelo,,,Prado Angelo,,,,,,,7-5 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,5,tsitsipas-b526f,,,Tsitsipas,,,,,,,pacheco-mendez,,,Pacheco Mendez,,,,,,,6-1 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,6,elamin,,,Elamin,,,,,,,makzoume-ae98c,,,Makzoume,,,,,,,6-3 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,7,suresh-f2001,,,Suresh,,,,,,,den-ouden,,,Den Ouden,,,,,,,6-4 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,8,wallin-c26c8,,,Wallin,,,,,,,mrva,,,Mrva,,,,,,,6-4 7-61,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,9,rinderknech,,,Rinderknech,,,,,,,molcan,,,Molcan,,,,,,,7-5 7-66,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,10,alazmeh-544a8,,,Alazmeh,,,,,,,agwi,,,Agwi,,,,,,,6-1 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,11,collignon,,,Collignon,,,,,,,ivanov-5f3c9,,,Ivanov,,,,,,,6-2 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,12,megalemos,,,Megalemos,,,,,,,aleksovski-9c23e,,,Aleksovski,,,,,,,7-68 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,13,ovcharenko-bb3a3,,,Ovcharenko,,,,,,,calzi,,,Calzi,,,,,,,6-4 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,14,nava-337db,,,Nava,,,,,,,fuele,,,Fuele,,,,,,,6-2 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,15,de-jong-57322,,,De Jong,,,,,,,nagal,,,Nagal,,,,,,,5-7 6-1 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,16,efstathiou-a23e0,,,Efstathiou,,,,,,,huseinovikj,,,Huseinovikj,,,,,,,6-2 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,17,duran-fd3b3,,,Duran,,,,,,,klegou,,,Klegou,,,,,,,6-2 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,18,mejia-a7d27,,,Mejia,,,,,,,bennani-3005c,,,Bennani,,,,,,,6-1 4-6 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,19,beckley,,,Beckley,,,,,,,krivokapic,,,Krivokapic,,,,,,,7-63 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,20,adeleye,,,Adeleye,,,,,,,ignatov,,,Ignatov,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,21,campbell-71163,,,Campbell,,,,,,,janev,,,Janev,,,,,,,6-2 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,22,henning-421d6,,,Henning,,,,,,,jovanovic-9f2af,,,Jovanovic,,,,,,,6-3 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,23,pieczonka-07acc,,,Pieczonka,,,,,,,ibrahim-6343c,,,Ibrahim,,,,,,,7-5 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,24,hiiesalu,,,Hiiesalu,,,,,,,yssel-0ee72,,,Yssel,,,,,,,6-2 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,25,chung-bdb8e,,,Chung,,,,,,,trungelliti,,,Trungelliti,,,,,,,6-4 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,26,virtanen-7d161,,,Virtanen,,,,,,,wong-d3ead,,,Wong,,,,,,,7-5 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,27,susanto-31f06,,,Susanto,,,,,,,kadangah-kili-5fa34,,,Kadangah Kili,,,,,,,6-1 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,28,sornlaksup,,,Sornlaksup,,,,,,,mesarovic,,,Mesarovic,,,,,,,2-6 6-4 11-9,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,29,kwon-b3d34,,,Kwon,,,,,,,tirante,,,Tirante,,,,,,,6-4 4-6 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,30,wu-f664e,,,Wu,,,,,,,hassan-1d510,,,Hassan,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,31,draxl,,,Draxl,,,,,,,heide-17a3d,,,Heide,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,32,shepp,,,Shepp,,,,,,,basic,,,Basic,,,,,,,6-2 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,33,watt-a298b,,,Watt,,,,,,,nedic,,,Nedic,,,,,,,6-3 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,34,diallo-dd116,,,Diallo,,,,,,,pucinelli-de-almeida,,,Pucinelli De Almeida,,,,,,,3-6 6-1 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260208,35,soto-fec8d,,,Soto,,,,,,,djuric-2d0e6,,,Djuric,,,,,,,62-7 7-64 10-7,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,36,vallejo-d7859,,,Vallejo,,,,,,,palosi,,,Palosi,,,,,,,6-1 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,37,andrade-58258,,,Andrade,,,,,,,duckworth,,,Duckworth,,,,,,,3-6 6-3 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,38,bicknell-8dc8a,,,Bicknell,,,,,,,aguilar-cardozo,,,Aguilar Cardozo,,,,,,,6-3 3-6 7-65,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,39,guillen-meza,,,Guillen Meza,,,,,,,hijikata,,,Hijikata,,,,,,,6-4 1-6 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,40,tsitsipas-b526f,,,Tsitsipas,,,,,,,magadan-68c65,,,Magadan,,,,,,,6-3 7-61,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,41,king-01912,,,King,,,,,,,dellien-e101c,,,Dellien,,,,,,,66-7 6-4 7-62,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,42,valeinis-ea0de,,,Valeinis,,,,,,,munoz-1a9fc,,,Munoz,,,,,,,7-5 66-7 10-6,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,43,roncadelli,,,Roncadelli,,,,,,,phillips-ad20d,,,Phillips,,,,,,,6-3 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,44,rinderknech,,,Rinderknech,,,,,,,gombos,,,Gombos,,,,,,,7-61 7-66,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,45,pacheco-mendez,,,Pacheco Mendez,,,,,,,sakellaridis-6aacb,,,Sakellaridis,,,,,,,6-2 4-6 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,46,prado-angelo,,,Prado Angelo,,,,,,,marshall-0d239,,,Marshall,,,,,,,6-3 4-6 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,47,quinn-d0193,,,Quinn,,,,,,,marozsan,,,Marozsan,,,,,,,3-6 6-3 7-611,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,48,blockx,,,Blockx,,,,,,,radulov,,,Radulov,,,,,,,63-7 6-4 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,49,brunold-a21c2,,,Brunold,,,,,,,ouakaa,,,Ouakaa,,,,,,,6-2 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,50,engel-6e09f,,,Engel,,,,,,,bueno-01b7e,,,Bueno,,,,,,,6-3 64-7 10-6,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,51,svrcina,,,Svrcina,,,,,,,wallin-c26c8,,,Wallin,,,,,,,6-1 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,52,montgomery-e782e,,,Montgomery,,,,,,,tkemaladze,,,Tkemaladze,,,,,,,2-6 7-64 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,53,prizmic,,,Prizmic,,,,,,,moller-6ea06,,,Moller,,,,,,,7-65 7-62,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,54,knaff,,,Knaff,,,,,,,orlov-d8e3f,,,Orlov,,,,,,,7-62 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,55,molcan,,,Molcan,,,,,,,muller-c81bc,,,Muller,,,,,,,6-4 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,56,suresh-f2001,,,Suresh,,,,,,,de-jong-57322,,,De Jong,,,,,,,6-4 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,57,buldorini,,,Buldorini,,,,,,,alazmeh-544a8,,,Alazmeh,,,,,,,7-65 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,58,vacherot,,,Vacherot,,,,,,,bublik-43f80,,,Bublik,,,,,,,7-64 7-67,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,59,mejia-a7d27,,,Mejia,,,,,,,baadi,,,Baadi,,,,,,,6-3 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,60,adeleye,,,Adeleye,,,,,,,usmonjonov,,,Usmonjonov,,,,,,,4-6 6-2 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,61,lehecka,,,Lehecka,,,,,,,madaras,,,Madaras,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,62,rodesch,,,Rodesch,,,,,,,krutykh,,,Krutykh,,,,,,,6-3 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,63,naw,,,Naw,,,,,,,agwi,,,Agwi,,,,,,,6-1 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,64,planinsek,,,Planinsek,,,,,,,kosaner,,,Kosaner,,,,,,,64-7 6-1 10-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,65,collignon,,,Collignon,,,,,,,vasilev-518d3,,,Vasilev,,,,,,,6-3 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,66,paul-324c3,,,Paul,,,,,,,piros,,,Piros,,,,,,,7-63 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,67,molder,,,Molder,,,,,,,van-schalkwyk,,,Van Schalkwyk,,,,,,,6-4 4-6 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,68,purtseladze,,,Purtseladze,,,,,,,phillips-48340,,,Phillips,,,,,,,6-4 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,69,gaubas,,,Gaubas,,,,,,,vales,,,Vales,,,,,,,6-1 3-6 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,70,klegou,,,Klegou,,,,,,,fuentes-vasquez,,,Fuentes Vásquez,,,,,,,1-6 7-65 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,71,kasnikowski,,,Kasnikowski,,,,,,,bassem-sobhy,,,Bassem Sobhy,,,,,,,6-1 7-67,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,72,den-ouden,,,Den Ouden,,,,,,,nagal,,,Nagal,,,,,,,6-0 4-6 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,73,photiades-30887,,,Photiades,,,,,,,micov,,,Micov,,,,,,,6-3 6-0,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,74,jovanovic-9f2af,,,Jovanovic,,,,,,,beckley,,,Beckley,,,,,,,6-2 3-6 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,75,bennani-3005c,,,Bennani,,,,,,,soriano-barrera,,,Soriano Barrera,,,,,,,7-64 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,76,lajal,,,Lajal,,,,,,,dippenaar,,,Dippenaar,,,,,,,6-1 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,77,sultanov,,,Sultanov,,,,,,,abua,,,Abua,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,78,henning-421d6,,,Henning,,,,,,,krivokapic,,,Krivokapic,,,,,,,6-4 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,79,efstathiou-a23e0,,,Efstathiou,,,,,,,huseinovikj,,,Huseinovikj,,,,,,,6-2 6-0,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,80,rodionov-f5e38,,,Rodionov,,,,,,,nishioka,,,Nishioka,,,,,,,5-7 6-1 6-0,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,81,duran-fd3b3,,,Duran,,,,,,,agbo-panzo,,,Agbo-Panzo,,,,,,,6-2 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,82,filar,,,Filar,,,,,,,zakaryia,,,Zakaryia,,,,,,,6-2 6-0,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,83,wong-d3ead,,,Wong,,,,,,,vasa,,,Vasa,,,,,,,6-4 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,84,shoaib,,,Shoaib,,,,,,,jadoun,,,Jadoun,,,,,,,7-5 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,85,neumayer,,,Neumayer,,,,,,,mochizuki-f2487,,,Mochizuki,,,,,,,6-3 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,86,virtanen-7d161,,,Virtanen,,,,,,,cheng-0aec1,,,Cheng,,,,,,,6-0 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,87,zhang-45ae9,,,Zhang,,,,,,,borges-8d823,,,Borges,,,,,,,7-5 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,88,kwon-b3d34,,,Kwon,,,,,,,trungelliti,,,Trungelliti,,,,,,,7-66 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,89,samrej-f05ce,,,Samrej,,,,,,,mesarovic,,,Mesarovic,,,,,,,6-2 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,90,barki-529e6,,,Barki,,,,,,,kwami-stanislas-roland,,,Kwami Stanislas Roland,,,,,,,6-0 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,91,hassan-1d510,,,Hassan,,,,,,,huang-5117a,,,Huang,,,,,,,6-4 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,92,jones-07763,,,Jones,,,,,,,alvarez-a038c,,,Alvarez,,,,,,,6-1 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,93,wu-f664e,,,Wu,,,,,,,habib,,,Habib,,,,,,,6-3 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,94,m-rifki,,,M Rifki,,,,,,,koffi-9aef8,,,Koffi,,,,,,,6-1 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,95,basic,,,Basic,,,,,,,watt-a298b,,,Watt,,,,,,,6-2 7-65,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,96,tirante,,,Tirante,,,,,,,chung-bdb8e,,,Chung,,,,,,,2-6 7-5 7-65,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,97,heide-17a3d,,,Heide,,,,,,,diallo-dd116,,,Diallo,,,,,,,7-64 3-6 7-63,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,98,draxl,,,Draxl,,,,,,,reis-da-silva,,,Reis Da Silva,,,,,,,6-3 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,99,tabilo,,,Tabilo,,,,,,,milic-b10f4,,,Milic,,,,,,,63-7 6-2 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,100,vallejo-d7859,,,Vallejo,,,,,,,ghetu,,,Ghetu,,,,,,,6-1 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260207,101,nedic,,,Nedic,,,,,,,shepp,,,Shepp,,,,,,,6-4 4-6 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,102,barrios-vera,,,Barrios Vera,,,,,,,lajovic,,,Lajovic,,,,,,,7-5 7-67,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,103,turcanu-14bcb,,,Turcanu,,,,,,,nunez-vera,,,Nunez Vera,,,,,,,6-1 3-6 7-62,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,104,fearnley,,,Fearnley,,,,,,,budkov-kjaer,,,Budkov Kjaer,,,,,,,3-6 6-3 10-7,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,105,hardt-79c77,,,Hardt,,,,,,,strombachs,,,Strombachs,,,,,,,7-5 62-7 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,106,struff,,,Struff,,,,,,,varillas,,,Varillas,,,,,,,6-4 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,107,prizmic,,,Prizmic,,,,,,,holmgren-a5794,,,Holmgren,,,,,,,5-7 6-0 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,108,purtseladze,,,Purtseladze,,,,,,,montgomery-e782e,,,Montgomery,,,,,,,6-2 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,109,hanfmann,,,Hanfmann,,,,,,,bueno-01b7e,,,Bueno,,,,,,,6-4 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,110,moller-6ea06,,,Moller,,,,,,,dodig-b6156,,,Dodig,,,,,,,6-4 7-63,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,111,cid-subervi,,,Cid Subervi,,,,,,,ozolins,,,Ozolins,,,,,,,7-66 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,112,riedi-a3a3d,,,Riedi,,,,,,,trifi,,,Trifi,,,,,,,6-1 6-0,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,113,erel,,,Erel,,,,,,,artnak,,,Artnak,,,,,,,7-62 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,114,kym,,,Kym,,,,,,,echargui,,,Echargui,,,,,,,7-62 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,115,alkaya,,,Alkaya,,,,,,,dominko,,,Dominko,,,,,,,7-5 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,116,phillips-48340,,,Phillips,,,,,,,bakshi-c841e,,,Bakshi,,,,,,,4-6 6-3 7-65,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,117,gaubas,,,Gaubas,,,,,,,shimanov,,,Shimanov,,,,,,,6-0 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,118,vacherot,,,Vacherot,,,,,,,shevchenko-3bd40,,,Shevchenko,,,,,,,6-0 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,119,bublik-43f80,,,Bublik,,,,,,,nys,,,Nys,,,,,,,6-0 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,120,butvilas,,,Butvilas,,,,,,,vales,,,Vales,,,,,,,7-63 6-0,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,121,khan-18a49,,,Khan,,,,,,,andre-ba2d1,,,Andre,,,,,,,63-7 7-66 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,122,rodionov-f5e38,,,Rodionov,,,,,,,mochizuki-f2487,,,Mochizuki,,,,,,,6-4 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,123,wu-9762d,,,Wu,,,,,,,borges-8d823,,,Borges,,,,,,,6-1 7-63,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,124,murtaza-68624,,,Murtaza,,,,,,,jadoun,,,Jadoun,,,,,,,6-3 1-6 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,125,watanuki-223ad,,,Watanuki,,,,,,,ofner-44428,,,Ofner,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260206,126,rocha-0492a,,,Rocha,,,,,,,yunchaokete,,,Yunchaokete,,,,,,,6-4 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260205,127,norrie,,,Norrie,,,,,,,budkov-kjaer,,,Budkov Kjaer,,,,,,,6-4 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-davis-cup,Davis Cup,Hard,,D,,20260205,128,draper-e73d3,,,Draper,,,,,,,durasovic,,,Durasovic,,,,,,,6-2 6-2,3,,,,,,,,,,,,,,,,,,,,
"""
        do {
            try csvData.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("  ❌ Failed to write embedded 2026.csv: \(error)")
        }
    }
}
