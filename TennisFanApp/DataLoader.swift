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
        
        // Parse scraped name: "Lastname F." or "Lastname-Part F." or "De Lastname F."
        // The initial is always the last part (single letter + optional period)
        let parts = trimmed.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        
        let lastPart = parts.last!
        // Check if last part is an initial (1-2 chars, possibly with period)
        let isInitial = lastPart.count <= 2 || (lastPart.count == 2 && lastPart.hasSuffix("."))
        
        guard isInitial else { return nil } // Not an abbreviated name
        
        let initial = lastPart.prefix(1).uppercased()
        let lastName = parts.dropLast().joined(separator: " ")
        
        // Search existing players for matching last name + first initial
        for (fullName, _) in playerDict {
            let fullParts = fullName.split(separator: " ").map(String.init)
            guard fullParts.count >= 2 else { continue }
            
            let fullFirstName = fullParts[0]
            let fullLastName = fullParts.dropFirst().joined(separator: " ")
            
            // Compare last names (case-insensitive, handle hyphens)
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
            print("⚠️ ATP_Database.csv not found — skipping player enrichment.")
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
        
        print("  ATP Database: \(db.count) player profiles loaded")
        return db
    }
    
    // MARK: - Main Load
    
    static func loadData(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Player>()
            let existing = try modelContext.fetch(descriptor)
            if !existing.isEmpty {
                print("Data already loaded (\(existing.count) players). Skipping.")
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
        print("✅ All seasons loaded. \(playerDict.count) unique players. (\(String(format: "%.1f", elapsed))s)")
        
        do {
            try modelContext.save()
            print("✅ Saved to database.")
        } catch {
            print("❌ Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Season Loading
    
    private static func loadSeason(from season: String, modelContext: ModelContext,
                                    playerDict: inout [String: Player],
                                    playerDB: [String: (height: Int?, backhand: String?, birthdate: Date?)]) {
        guard let url = Bundle.main.url(forResource: season, withExtension: "csv") else {
            print("⚠️ \(season).csv not found in bundle — skipping.")
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
        
        print("  \(season): \(gamesAdded) matches loaded")
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
            print("  ⚠️ No 2026.csv found — skipping.")
            return
        }
        
        // Load using the same parser, but from Documents URL
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        var gamesAdded = 0
        
        do {
            let content = try String(contentsOf: docsURL, encoding: .utf8)
            let lines = content.split(separator: "\n")
            print("  2026 (Documents): \(lines.count) lines")
            guard lines.count > 1 else {
                print("  ⚠️ 2026.csv has no data rows")
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
        
        print("  2026: \(gamesAdded) matches loaded")
    }
    
    /// Write 2026 CSV data directly to Documents (bypasses Xcode bundle issues)
    private static func seed2026FromEmbedded(to url: URL) {
        let csvData = """
tourney_id,tourney_name,surface,draw_size,tourney_level,indoor,tourney_date,match_num,winner_id,winner_seed,winner_entry,winner_name,winner_hand,winner_ht,winner_ioc,winner_age,winner_rank,winner_rank_points,loser_id,loser_seed,loser_entry,loser_name,loser_hand,loser_ht,loser_ioc,loser_age,loser_rank,loser_rank_points,score,best_of,round,minutes,w_ace,w_df,w_svpt,w_1stIn,w_1stWon,w_2ndWon,w_SvGms,w_bpSaved,w_bpFaced,l_ace,l_df,l_svpt,l_1stIn,l_1stWon,l_2ndWon,l_SvGms,l_bpSaved,l_bpFaced
2026-united-cup,United Cup,Hard,,D,,20260101,1,baez-a8fb1,,,Baez S.,,,,,,,fritz-f1aa7,,,Fritz T.,,,,,,,4-6 7-5 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260101,2,ruud-dfb38,,,Ruud C.,,,,,,,de-minaur,,,De Minaur A.,,,,,,,6-3 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260101,3,wawrinka-ffdb9,,,Wawrinka S.,,,,,,,rinderknech,,,Rinderknech A.,,,,,,,5-7 7-65 7-65,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260101,4,zhang-45ae9,,,Zhang Z.,,,,,,,bergs,,,Bergs Z.,,,,,,,62-7 7-63 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260101,5,dedura-palomero-d612d,,,Dedura-Palomero D.,,,,,,,bennani-3005c,,,Bennani R.,,,,,,,6-2 6-0,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260101,6,cuenin,,,Cuenin S.,,,,,,,jianu-c67fb,,,Jianu F.,,,,,,,6-2 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260101,7,d-agostino,,,D'Agostino S.,,,,,,,baragiola-mordini,,,Baragiola Mordini T.,,,,,,,6-2 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-united-cup,United Cup,Hard,,D,,20260101,8,kelm,,,Kelm Y.,,,,,,,dugardin,,,Dugardin R.,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,1,arnaldi,1,,Arnaldi M.,,,,,,,gaston-e1fa4,,,Gaston H.,,,,,,,6-1 5-7 7-65,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,2,halys,,,Halys Q.,,,,,,,spizzirri,11,,Spizzirri E.,,,,,,,6-4 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,3,majchrzak-905d8,2,,Majchrzak K.,,,,,,,hewitt-d8622,,,Hewitt C.,,,,,,,6-4 7-5,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,4,hijikata,,,Hijikata R.,,,,,,,misolic,8,,Misolic F.,,,,,,,6-3 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,5,duckworth,10,,Duckworth J.,,,,,,,schoolkate,,,Schoolkate T.,,,,,,,6-3 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,6,atmane,3,,Atmane T.,,,,,,,hanfmann,,,Hanfmann Y.,,,,,,,6-4 7-63,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,7,o-connell-020b8,,,O'Connell C.,,,,,,,basilashvili,,,Basilashvili N.,,,,,,,6-2 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,8,quinn-d0193,5,,Quinn E.,,,,,,,bonzi-a38fa,,,Bonzi B.,,,,,,,4-6 6-3 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,9,sweeny,,,Sweeny D.,,,,,,,fearnley,6,,Fearnley J.,,,,,,,6-1 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,10,cazaux,4,,Cazaux A.,,,,,,,landaluce-84126,,,Landaluce M.,,,,,,,6-3 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,11,carreno-busta,,,Carreno-Busta P.,,,,,,,bellucci-47e7e,7,,Bellucci M.,,,,,,,6-4 2-6 7-63,3,,,,,,,,,,,,,,,,,,,,
2026-brisbane,Brisbane,Hard,,250,,20260101,12,collignon,9,,Collignon R.,,,,,,,shevchenko-3bd40,,,Shevchenko A.,,,,,,,7-5 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260201,1,blanchet,,,Blanchet U.,,,,,,,vavassori,,,Vavassori A.,,,,,,,6-4 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260201,2,fils,6,,Fils A.,,,,,,,royer,,,Royer V.,,,,,,,7-67 64-7 6-2,3,,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260201,3,humbert-e2553,5,,Humbert U.,,,,,,,van-de-zandschulp,,,Van De Zandschulp B.,,,,,,,6-3 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260201,4,droguet,,,Droguet T.,,,,,,,choinski,,,Choinski J.,,,,,,,6-2 7-62,3,,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260201,5,damm-4f98a,,,Damm M.,,,,,,,hurkacz,7,,Hurkacz H.,,,,,,,7-65 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-montpellier,Montpellier,,,250,,20260201,6,carreno-busta,,,Carreno-Busta P.,,,,,,,kecmanovic,,,Kecmanovic M.,,,,,,,4-6 6-3 7-64,3,,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260301,1,mcdonald-4d935,,,McDonald M.,,,,,,,sachko,,,Sachko V.,,,,,,,6-2 6-1,3,,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260301,2,burruchaga,6,,Burruchaga R.,,,,,,,echargui,,,Echargui M.,,,,,,,7-64 4-6 7-65,3,,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260301,3,kopriva,1,,Kopriva V.,,,,,,,sakamoto-9c9d5,,,Sakamoto R.,,,,,,,6-4 7-66,3,,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260301,4,barrios-vera,14,,Barrios Vera M.,,,,,,,leach-cc0c0,,,Leach J.,,,,,,,6-3 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260301,5,galarneau-32e1f,,,Galarneau A.,,,,,,,van-assche,7,,Van Assche L.,,,,,,,7-66 6-4,3,,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260301,6,svajda-cce6f,,,Svajda T.,,,,,,,nardi-e2cda,12,,Nardi L.,,,,,,,4-6 7-62 6-3,3,,,,,,,,,,,,,,,,,,,,
2026-indian-wells,Indian Wells,Hard,,M,,20260301,7,svrcina,,,Svrcina D.,,,,,,,krueger-d6035,,,Krueger M.,,,,,,,7-66 6-4,3,,,,,,,,,,,,,,,,,,,,
"""
        do {
            try csvData.write(to: url, atomically: true, encoding: .utf8)
            print("  ✅ Seeded 2026.csv from embedded data (\(csvData.count) chars)")
        } catch {
            print("  ❌ Failed to write embedded 2026.csv: \(error)")
        }
    }
}
