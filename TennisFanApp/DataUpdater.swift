//
//  DataUpdater.swift
//  TennisFanApp
//
//  Downloads updated 2026.csv from GitHub and refreshes the database.
//

import Foundation
import SwiftData

class DataUpdater {
    
    static let csvURL = URL(string: "https://raw.githubusercontent.com/alaingendre/TennisFanApp/main/2026.csv")!
    
    private static let lastUpdateKey = "lastUpdate2026"
    private static let lastHashKey = "lastHash2026"
    
    // MARK: - Check & Download
    
    /// Check if a newer 2026.csv is available and download it.
    /// Returns true if new data was downloaded and saved.
    static func checkForUpdate() async -> Bool {
        do {
            // Download the file
            var request = URLRequest(url: csvURL)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("  ⚠️ Update check: bad HTTP response")
                return false
            }
            
            // Try UTF-8 first, then Latin1
            guard let csvString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                print("  ⚠️ Update check: can't decode data (\(data.count) bytes)")
                return false
            }
            
            // Normalize line endings and count lines
            let normalized = csvString
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            let lines = normalized.components(separatedBy: "\n").filter { !$0.isEmpty }
            let lineCount = lines.count
            
            print("  📊 Download: \(data.count) bytes, \(lineCount) lines (raw split: \(csvString.split(separator: "\n").count))")
            
            guard normalized.contains("tourney_id"), lineCount > 1 else {
                print("  ⚠️ Update check: invalid CSV content (\(data.count) bytes, \(lineCount) lines)")
                print("  ⚠️ Preview: \(String(csvString.prefix(100)))")
                return false
            }
            
            // Compare using byte count only (most reliable)
            let newHash = "\(data.count)"
            let oldHash = UserDefaults.standard.string(forKey: lastHashKey) ?? ""
            
            if newHash == oldHash {
                print("  ✅ 2026.csv unchanged (\(lineCount) lines)")
                return false
            }
            
            // Save to Documents
            let localURL = DataLoader.get2026URL()
            try data.write(to: localURL)
            
            UserDefaults.standard.set(newHash, forKey: lastHashKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastUpdateKey)
            
            print("  📥 Downloaded new 2026.csv: \(lineCount) lines, \(data.count) bytes")
            return true
            
        } catch {
            print("  ⚠️ Update check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Reload 2026 Data
    
    /// Reload 2026 matches from the updated CSV into the database.
    /// Parses new data first, only deletes old data if parsing succeeds.
    static func reload2026(modelContext: ModelContext) {
        let url = DataLoader.get2026URL()
        guard let rawContent = try? String(contentsOf: url, encoding: .utf8) else {
            print("  ⚠️ reload2026: can't read file")
            return
        }
        
        let content = rawContent.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = content.split(separator: "\n")
        guard lines.count > 1 else {
            print("  ⚠️ reload2026: no data rows")
            return
        }
        
        // Build player dictionary from existing players
        var playerDict: [String: Player] = [:]
        if let players = try? modelContext.fetch(FetchDescriptor<Player>()) {
            for p in players {
                playerDict[p.name] = p
            }
        }
        
        // Parse new matches first (don't touch database yet)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        
        struct ParsedMatch {
            let matchKey: String
            let tournamentName: String
            let surface: String
            let tourneyLevel: String
            let drawSize: Int
            let round: String
            let bestOf: Int
            let matchDate: Date
            let score: String
            let season: String
            let winnerName: String
            let loserName: String
            let winnerSeed: Int?
            let loserSeed: Int?
        }
        
        var parsed: [ParsedMatch] = []
        
        for (i, line) in lines.enumerated() {
            if i == 0 { continue }
            
            // Use proper CSV parsing (handle commas in quoted fields)
            let col = parseCSVLine(String(line))
            guard col.count >= 31 else { continue }
            
            let rawWinner = col[11]
            let rawLoser = col[21]
            guard !rawWinner.isEmpty, !rawLoser.isEmpty else { continue }
            guard let matchDate = dateFormatter.date(from: col[6]) else { continue }
            
            // Match abbreviated names to existing players
            let winnerName = matchName(rawWinner, in: playerDict) ?? rawWinner
            let loserName = matchName(rawLoser, in: playerDict) ?? rawLoser
            
            parsed.append(ParsedMatch(
                matchKey: "\(col[0])_\(col[7])",
                tournamentName: col[1],
                surface: col[2],
                tourneyLevel: col[4],
                drawSize: Int(col[3]) ?? 0,
                round: col[30],
                bestOf: Int(col[29]) ?? 3,
                matchDate: matchDate,
                score: col[28],
                season: "2026",
                winnerName: winnerName,
                loserName: loserName,
                winnerSeed: Int(col[9]),
                loserSeed: Int(col[19])
            ))
        }
        
        guard !parsed.isEmpty else {
            print("  ⚠️ reload2026: parsed 0 matches, keeping existing data")
            return
        }
        
        print("  🔄 reload2026: parsed \(parsed.count) matches, replacing old data...")
        
        // NOW delete old 2026 games (safe because we have new data ready)
        let descriptor = FetchDescriptor<Game>(
            predicate: #Predicate<Game> { $0.season == "2026" }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for game in existing {
                modelContext.delete(game)
            }
            print("  🗑️ Removed \(existing.count) old 2026 matches")
        }
        
        // Insert new matches
        for m in parsed {
            // Get or create winner
            if playerDict[m.winnerName] == nil {
                let p = Player(playerId: "", name: m.winnerName, hand: "U", countryCode: "")
                modelContext.insert(p)
                playerDict[m.winnerName] = p
            }
            let winner = playerDict[m.winnerName]!
            
            // Get or create loser
            if playerDict[m.loserName] == nil {
                let p = Player(playerId: "", name: m.loserName, hand: "U", countryCode: "")
                modelContext.insert(p)
                playerDict[m.loserName] = p
            }
            let loser = playerDict[m.loserName]!
            
            let game = Game(
                matchKey: m.matchKey,
                tournamentName: m.tournamentName,
                surface: m.surface,
                tourneyLevel: m.tourneyLevel,
                drawSize: m.drawSize,
                round: m.round,
                bestOf: m.bestOf,
                matchDate: m.matchDate,
                score: m.score,
                season: "2026",
                winner: winner,
                loser: loser,
                winnerSeed: m.winnerSeed,
                loserSeed: m.loserSeed
            )
            modelContext.insert(game)
        }
        
        do {
            try modelContext.save()
            print("  ✅ reload2026: \(parsed.count) matches saved")
        } catch {
            print("  ❌ reload2026 save failed: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    static func lastUpdateDate() -> Date? {
        let ts = UserDefaults.standard.double(forKey: lastUpdateKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
    
    /// Parse CSV line handling quoted fields
    private static func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var insideQuotes = false
        for char in line {
            if char == "\"" { insideQuotes.toggle() }
            else if char == "," && !insideQuotes { columns.append(current); current = "" }
            else { current.append(char) }
        }
        columns.append(current)
        return columns
    }
    
    /// Match abbreviated scraped name to existing full name
    private static func matchName(_ scraped: String, in dict: [String: Player]) -> String? {
        if dict[scraped] != nil { return scraped }
        
        let parts = scraped.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        let lastPart = parts.last!
        guard lastPart.count <= 2 || (lastPart.count == 2 && lastPart.hasSuffix(".")) else { return nil }
        
        let initial = lastPart.prefix(1).uppercased()
        let lastName = parts.dropLast().joined(separator: " ")
        
        for (fullName, _) in dict {
            let fullParts = fullName.split(separator: " ").map(String.init)
            guard fullParts.count >= 2 else { continue }
            if fullParts.dropFirst().joined(separator: " ").lowercased().replacingOccurrences(of: "-", with: " ")
                == lastName.lowercased().replacingOccurrences(of: "-", with: " ")
                && fullParts[0].prefix(1).uppercased() == initial {
                return fullName
            }
        }
        return nil
    }
}
