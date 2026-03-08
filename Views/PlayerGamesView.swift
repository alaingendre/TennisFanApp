//
//  PlayerGamesView.swift
//  TennisFanApp
//
//  Created by Alain Gendre on 11/28/25.
//

import SwiftUI
import SwiftData

// Tournament level to display name/emoji
func tourneyBadge(_ level: String) -> String {
    switch level {
    case "G": return "🏆"   // Grand Slam
    case "M": return "⭐"   // Masters 1000
    case "F": return "🏅"   // ATP Finals
    case "A": return "🎾"   // ATP 500
    case "D": return "🏳️"  // Davis Cup
    default:  return ""      // ATP 250 and others
    }
}

func tourneyLevelName(_ level: String) -> String {
    switch level {
    case "G": return "Grand Slam"
    case "M": return "Masters 1000"
    case "F": return "ATP Finals"
    case "A": return "ATP 500"
    case "250": return "ATP 250"
    case "D": return "Davis Cup"
    case "500": return "ATP 500"
    default: return ""
    }
}

struct PlayerGamesView: View {
    let player: Player
    let selectedYear: String
    @Environment(\.modelContext) private var modelContext
    @Query private var allAttendance: [Attendance]
    @State private var playerGames: [Game] = []
    @State private var showMetric = true
    
    var attendedKeys: Set<String> {
        Set(allAttendance.map { $0.matchKey })
    }
    
    var pastGames: [Game] {
        // A match is "past" if it has a score OR its date is before today
        playerGames.filter { !$0.score.isEmpty || $0.matchDate < Date() }
    }
    
    var upcomingGames: [Game] {
        // A match is "upcoming" only if it has NO score AND its date is today or later
        playerGames.filter { $0.score.isEmpty && $0.matchDate >= Date() }
    }
    
    var winsCount: Int {
        playerGames.filter { $0.winner.playerId == player.playerId }.count
    }
    
    var lossesCount: Int {
        playerGames.filter { $0.loser.playerId == player.playerId }.count
    }
    
    var playerAge: Int? {
        guard let birthdate = player.birthdate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthdate, to: Date())
        return components.year
    }

    var body: some View {
        List {
            // Player Info
            Section {
                HStack {
                    Text(flag(for: player.countryCode))
                        .font(.system(size: 60))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(player.name)
                            .font(.title)
                            .bold()
                        HStack(spacing: 12) {
                            Label(player.countryCode, systemImage: "globe")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let age = playerAge {
                                Label("\(age) yrs", systemImage: "calendar")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let ht = player.height {
                                Button(action: { showMetric.toggle() }) {
                                    let totalInches = Double(ht) / 2.54
                                    let feet = Int(totalInches) / 12
                                    let inches = Int(totalInches) % 12
                                    let meters = String(format: "%.2f", Double(ht) / 100.0)
                                    Label(showMetric ? "\(meters)m" : "\(feet)'\(inches)\"",
                                          systemImage: "ruler")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        HStack(spacing: 12) {
                            if player.hand != "U" {
                                Label(player.hand == "R" ? "Right-handed" : "Left-handed", systemImage: "hand.raised")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let bh = player.backhand {
                                Text("• \(bh == "2H" ? "Two-handed BH" : "One-handed BH")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Stats
            Section("Statistics — \(selectedYear)") {
                HStack {
                    Text("Total Matches")
                    Spacer()
                    Text("\(playerGames.count)").bold()
                }
                HStack {
                    Text("Wins")
                    Spacer()
                    Text("\(winsCount)").bold().foregroundColor(.green)
                }
                HStack {
                    Text("Losses")
                    Spacer()
                    Text("\(lossesCount)").bold().foregroundColor(.red)
                }
                if let bestRank = playerGames.compactMap({
                    $0.winner.playerId == player.playerId ? $0.winnerRank : $0.loserRank
                }).min() {
                    HStack {
                        Text("Best Ranking")
                        Spacer()
                        Text("#\(bestRank)").bold().foregroundColor(.blue)
                    }
                }
            }
            
            // Upcoming
            if !upcomingGames.isEmpty {
                Section("Upcoming Matches (\(upcomingGames.count))") {
                    ForEach(upcomingGames) { game in
                        GameRowView(game: game, player: player, isAttended: attendedKeys.contains(game.matchKey))
                    }
                }
            }
            
            // Past
            if !pastGames.isEmpty {
                Section("Past Matches (\(pastGames.count))") {
                    ForEach(pastGames) { game in
                        GameRowView(game: game, player: player, isAttended: attendedKeys.contains(game.matchKey))
                    }
                }
            }
            
            if playerGames.isEmpty {
                Section {
                    Text("No matches found for this player in \(selectedYear).")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .navigationTitle("\(player.name) — \(selectedYear)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadPlayerGames() }
    }
    
    private func loadPlayerGames() {
        let pid = player.playerId
        let year = selectedYear
        let descriptor = FetchDescriptor<Game>(
            predicate: #Predicate<Game> { game in
                game.season == year &&
                (game.winner.playerId == pid || game.loser.playerId == pid)
            },
            sortBy: [SortDescriptor(\Game.matchDate, order: .reverse),
                     SortDescriptor(\Game.matchKey, order: .reverse)]
        )
        playerGames = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Game Row View
struct GameRowView: View {
    let game: Game
    let player: Player
    let isAttended: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var showStats = false
    
    var isWin: Bool {
        game.winner.playerId == player.playerId
    }
    
    var opponent: Player {
        isWin ? game.loser : game.winner
    }
    
    var opponentRank: Int? {
        isWin ? game.loserRank : game.winnerRank
    }
    
    var opponentSeed: Int? {
        isWin ? game.loserSeed : game.winnerSeed
    }
    
    var hasStats: Bool {
        game.wAce != nil || game.minutes != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tournament, level badge, and date
            HStack {
                Text(tourneyBadge(game.tourneyLevel))
                Text(game.tournamentName)
                    .font(.headline)
                Spacer()
                Text(game.matchDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Opponent with rank
            HStack {
                Text(flag(for: opponent.countryCode))
                Text("vs \(opponent.name)")
                    .font(.subheadline)
                if let rank = opponentRank {
                    Text("#\(rank)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(rank <= 10 ? Color.purple : Color.gray)
                        .cornerRadius(4)
                }
                if let seed = opponentSeed {
                    Text("[\(seed)]")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(isWin ? "W" : "L")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isWin ? Color.green : Color.red)
                    .cornerRadius(4)
            }
            
            // Round, Surface, Score, Duration
            HStack {
                Text(game.round)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("•").foregroundColor(.secondary)
                Text(game.surface)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !game.score.isEmpty {
                    Text("•").foregroundColor(.secondary)
                    Text(game.score)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let min = game.minutes, min > 0 {
                    Text("•").foregroundColor(.secondary)
                    Text("\(min) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Stats button
                if hasStats {
                    Button {
                        showStats.toggle()
                    } label: {
                        Image(systemName: "chart.bar")
                            .font(.body)
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
                
                // Attendance toggle
                Button {
                    toggleAttendance()
                } label: {
                    Image(systemName: isAttended ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundColor(isAttended ? .blue : .gray)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
            
            // Expandable stats
            if showStats {
                MatchStatsView(game: game, isWin: isWin)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toggleAttendance() {
        if isAttended {
            let key = game.matchKey
            let descriptor = FetchDescriptor<Attendance>(predicate: #Predicate { $0.matchKey == key })
            if let existing = try? modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
            }
        } else {
            modelContext.insert(Attendance(matchKey: game.matchKey))
        }
        try? modelContext.save()
    }
}

// MARK: - Match Stats View
struct MatchStatsView: View {
    let game: Game
    let isWin: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Divider()
            
            HStack {
                Text(isWin ? game.winner.name : game.loser.name)
                    .font(.caption2).bold()
                Spacer()
                Text("Stats")
                    .font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text(isWin ? game.loser.name : game.winner.name)
                    .font(.caption2).bold()
            }
            
            if isWin {
                statRow("Aces", left: game.wAce, right: game.lAce)
                statRow("Double Faults", left: game.wDf, right: game.lDf)
                statRow("Break Pts Saved", left: bpString(saved: game.wBpSaved, faced: game.wBpFaced),
                         right: bpString(saved: game.lBpSaved, faced: game.lBpFaced))
                if let w1st = game.w1stIn, let wSvpt = game.wSvpt, wSvpt > 0,
                   let l1st = game.l1stIn, let lSvpt = game.lSvpt, lSvpt > 0 {
                    statRow("1st Serve %",
                            left: "\(Int(Double(w1st)/Double(wSvpt)*100))%",
                            right: "\(Int(Double(l1st)/Double(lSvpt)*100))%")
                }
            } else {
                statRow("Aces", left: game.lAce, right: game.wAce)
                statRow("Double Faults", left: game.lDf, right: game.wDf)
                statRow("Break Pts Saved", left: bpString(saved: game.lBpSaved, faced: game.lBpFaced),
                         right: bpString(saved: game.wBpSaved, faced: game.wBpFaced))
                if let l1st = game.l1stIn, let lSvpt = game.lSvpt, lSvpt > 0,
                   let w1st = game.w1stIn, let wSvpt = game.wSvpt, wSvpt > 0 {
                    statRow("1st Serve %",
                            left: "\(Int(Double(l1st)/Double(lSvpt)*100))%",
                            right: "\(Int(Double(w1st)/Double(wSvpt)*100))%")
                }
            }
        }
        .padding(.top, 4)
    }
    
    private func statRow(_ label: String, left: Int?, right: Int?) -> some View {
        HStack {
            Text(left.map { "\($0)" } ?? "—")
                .font(.caption).frame(width: 40, alignment: .leading)
            Spacer()
            Text(label)
                .font(.caption2).foregroundColor(.secondary)
            Spacer()
            Text(right.map { "\($0)" } ?? "—")
                .font(.caption).frame(width: 40, alignment: .trailing)
        }
    }
    
    private func statRow(_ label: String, left: String, right: String) -> some View {
        HStack {
            Text(left)
                .font(.caption).frame(width: 40, alignment: .leading)
            Spacer()
            Text(label)
                .font(.caption2).foregroundColor(.secondary)
            Spacer()
            Text(right)
                .font(.caption).frame(width: 40, alignment: .trailing)
        }
    }
    
    private func bpString(saved: Int?, faced: Int?) -> String {
        guard let s = saved, let f = faced else { return "—" }
        return "\(s)/\(f)"
    }
}
