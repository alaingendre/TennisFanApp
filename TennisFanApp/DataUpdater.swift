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
    private static let lastSizeKey = "lastSize2026"
    
    // MARK: - Check & Download
    
    /// Check if a newer 2026.csv is available and download it.
    /// Returns true if new data was downloaded.
    static func checkForUpdate() async -> Bool {
        do {
            // HEAD request to check file size (fast, no full download)
            var headRequest = URLRequest(url: csvURL)
            headRequest.httpMethod = "HEAD"
            headRequest.timeoutInterval = 10
            
            let (_, headResponse) = try await URLSession.shared.data(for: headRequest)
            guard let httpResponse = headResponse as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("  ⚠️ Update check failed: bad response")
                return false
            }
            
            let remoteSize = httpResponse.expectedContentLength
            let localSize = Int64(UserDefaults.standard.integer(forKey: lastSizeKey))
            
            // If same size, no update needed
            if remoteSize > 0 && remoteSize == localSize {
                print("  ✅ 2026.csv is up to date (\(remoteSize) bytes)")
                return false
            }
            
            // Download the full file
            print("  📥 Downloading updated 2026.csv (\(remoteSize) bytes)...")
            let (data, _) = try await URLSession.shared.data(from: csvURL)
            
            guard let csvString = String(data: data, encoding: .utf8),
                  csvString.contains("tourney_id") else {
                print("  ⚠️ Downloaded file doesn't look like valid CSV")
                return false
            }
            
            let lineCount = csvString.components(separatedBy: "\n").count
            print("  📥 Downloaded \(data.count) bytes, \(lineCount) lines")
            
            // Only update if we got more data than what we have
            let localURL = DataLoader.get2026URL()
            if let existingContent = try? String(contentsOf: localURL, encoding: .utf8) {
                let existingLines = existingContent.components(separatedBy: "\n").count
                if lineCount <= existingLines {
                    print("  ✅ No new matches (remote: \(lineCount) lines, local: \(existingLines) lines)")
                    UserDefaults.standard.set(Int(remoteSize), forKey: lastSizeKey)
                    return false
                }
            }
            
            // Save to Documents
            try data.write(to: localURL)
            UserDefaults.standard.set(Int(remoteSize), forKey: lastSizeKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastUpdateKey)
            
            print("  ✅ Updated 2026.csv: \(lineCount) lines saved")
            return true
            
        } catch {
            print("  ⚠️ Update check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Reload 2026 Data
    
    /// Reload 2026 matches from the updated CSV into the database.
    static func reload2026(modelContext: ModelContext) {
        // Delete existing 2026 games
        let descriptor = FetchDescriptor<Game>(
            predicate: #Predicate<Game> { $0.season == "2026" }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for game in existing {
                modelContext.delete(game)
            }
            print("  🗑️ Removed \(existing.count) old 2026 matches")
        }
        
        // Reload from updated CSV
        // We need the player dict and playerDB — fetch existing players
        var playerDict: [String: Player] = [:]
        if let players = try? modelContext.fetch(FetchDescriptor<Player>()) {
            for p in players {
                playerDict[p.name] = p
            }
        }
        
        let playerDB = loadPlayerDBQuick()
        
        // Load 2026 from Documents
        load2026(modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
        
        try? modelContext.save()
    }
    
    // MARK: - Helpers
    
    static func lastUpdateDate() -> Date? {
        let ts = UserDefaults.standard.double(forKey: lastUpdateKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
    
    /// Quick player DB load (just for enrichment during 2026 reload)
    private static func loadPlayerDBQuick() -> [String: (height: Int?, backhand: String?, birthdate: Date?)] {
        guard let url = Bundle.main.url(forResource: "ATP_Database", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        var db: [String: (height: Int?, backhand: String?, birthdate: Date?)] = [:]
        
        let lines = content.split(separator: "\n")
        for (i, line) in lines.enumerated() {
            if i == 0 { continue }
            let col = line.split(separator: ",", omittingEmptySubsequences: false).map { 
                String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            guard col.count >= 12 else { continue }
            db[col[0]] = (Int(col[5]), col[10].isEmpty ? nil : col[10], dateFormatter.date(from: col[3]))
        }
        return db
    }
    
    /// Load 2026 matches from Documents CSV (reuses DataLoader's parsing logic)
    private static func load2026(modelContext: ModelContext,
                                  playerDict: inout [String: Player],
                                  playerDB: [String: (height: Int?, backhand: String?, birthdate: Date?)]) {
        let url = DataLoader.get2026URL()
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        
        let lines = content.split(separator: "\n")
        guard lines.count > 1 else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        var added = 0
        
        // Simple column indices for 2024+ format (has indoor)
        for (i, line) in lines.enumerated() {
            if i == 0 { continue }
            let col = String(line).split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard col.count >= 31 else { continue }
            
            let matchKey = "\(col[0])_\(col[7])"
            let rawWinner = col[11]
            let rawLoser = col[21]
            guard !rawWinner.isEmpty, !rawLoser.isEmpty else { continue }
            guard let matchDate = dateFormatter.date(from: col[6]) else { continue }
            
            // Match abbreviated names to existing players
            let winnerName = matchName(rawWinner, in: playerDict) ?? rawWinner
            let loserName = matchName(rawLoser, in: playerDict) ?? rawLoser
            
            // Get or create winner
            if playerDict[winnerName] == nil {
                let p = Player(playerId: col[8], name: winnerName, hand: "U", countryCode: "")
                modelContext.insert(p)
                playerDict[winnerName] = p
            }
            let winner = playerDict[winnerName]!
            
            // Get or create loser
            if playerDict[loserName] == nil {
                let p = Player(playerId: col[18], name: loserName, hand: "U", countryCode: "")
                modelContext.insert(p)
                playerDict[loserName] = p
            }
            let loser = playerDict[loserName]!
            
            let game = Game(
                matchKey: matchKey,
                tournamentName: col[1],
                surface: col[2],
                tourneyLevel: col[4],
                drawSize: Int(col[3]) ?? 0,
                round: col[30],
                bestOf: Int(col[29]) ?? 3,
                matchDate: matchDate,
                score: col[28],
                season: "2026",
                winner: winner,
                loser: loser,
                winnerSeed: Int(col[9]),
                loserSeed: Int(col[19])
            )
            modelContext.insert(game)
            added += 1
        }
        
        print("  2026: \(added) matches loaded from update")
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
