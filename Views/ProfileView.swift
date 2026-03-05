//
//  ProfileView.swift
//  TennisFanApp
//
//  Created by Alain Gendre on 11/28/25.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAttendance: [Attendance]
    @State private var attendedGames: [Game] = []
    
    var playersSeen: [Player] {
        var dict: [String: Player] = [:]
        for game in attendedGames {
            dict[game.winner.playerId] = game.winner
            dict[game.loser.playerId] = game.loser
        }
        return Array(dict.values).sorted { $0.name < $1.name }
    }
    
    var tournamentsAttended: [(tournament: String, years: [String])] {
        var dict: [String: Set<String>] = [:]
        for game in attendedGames {
            dict[game.tournamentName, default: Set()].insert(game.season)
        }
        return dict.map { ($0.key, Array($0.value).sorted(by: >)) }
            .sorted { $0.tournament < $1.tournament }
    }

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("Your Tennis Journey")
                        .font(.title2)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            
            // Stats
            Section("Your Statistics") {
                NavigationLink(destination: AttendedGamesListView(games: attendedGames)) {
                    HStack {
                        Image(systemName: "tennisball.fill").foregroundColor(.green)
                        Text("Games Attended")
                        Spacer()
                        Text("\(attendedGames.count)").bold().foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: PlayersSeenListView(players: playersSeen, attendedKeys: Set(allAttendance.map { $0.matchKey }))) {
                    HStack {
                        Image(systemName: "person.2.fill").foregroundColor(.orange)
                        Text("Unique Players Seen")
                        Spacer()
                        Text("\(playersSeen.count)").bold().foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: TournamentsListView(tournaments: tournamentsAttended)) {
                    HStack {
                        Image(systemName: "trophy.fill").foregroundColor(.yellow)
                        Text("Tournaments Attended")
                        Spacer()
                        Text("\(tournamentsAttended.count)").bold().foregroundColor(.secondary)
                    }
                }
            }
            
            // Empty state
            if attendedGames.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No games attended yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Mark games as attended in player profiles to track your tennis journey!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Profile")
        .onAppear { loadAttendedGames() }
    }
    
    private func loadAttendedGames() {
        let keys = allAttendance.map { $0.matchKey }
        guard !keys.isEmpty else {
            attendedGames = []
            return
        }
        let descriptor = FetchDescriptor<Game>(
            predicate: #Predicate<Game> { game in
                keys.contains(game.matchKey)
            }
        )
        attendedGames = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Attended Games List
struct AttendedGamesListView: View {
    let games: [Game]
    
    var gamesByYear: [(year: String, games: [Game])] {
        var dict: [String: [Game]] = [:]
        for game in games {
            dict[game.season, default: []].append(game)
        }
        return dict.keys.sorted(by: >).map { year in
            (year, dict[year]!.sorted { $0.matchDate > $1.matchDate })
        }
    }
    
    var body: some View {
        List {
            ForEach(gamesByYear, id: \.year) { yearData in
                NavigationLink(destination: YearGamesDetailView(year: yearData.year, games: yearData.games)) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(yearData.year).font(.headline)
                            Text("\(yearData.games.count) games")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Games Attended (\(games.count))")
    }
}

// MARK: - Year Games Detail
struct YearGamesDetailView: View {
    let year: String
    let games: [Game]
    
    var body: some View {
        List {
            ForEach(games) { game in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(tourneyBadge(game.tourneyLevel))
                        Text(game.tournamentName).font(.headline)
                        Spacer()
                        Text(game.matchDate, style: .date)
                            .font(.caption).foregroundColor(.secondary)
                    }
                    HStack {
                        Text(flag(for: game.winner.countryCode))
                        Text(game.winner.name).font(.subheadline)
                        Text("vs").font(.caption).foregroundColor(.secondary)
                        Text(flag(for: game.loser.countryCode))
                        Text(game.loser.name).font(.subheadline)
                    }
                    HStack {
                        Text(game.round).font(.caption).foregroundColor(.secondary)
                        Text("•").foregroundColor(.secondary)
                        Text(game.surface).font(.caption).foregroundColor(.secondary)
                        if !game.score.isEmpty {
                            Text("•").foregroundColor(.secondary)
                            Text(game.score).font(.caption).foregroundColor(.secondary)
                        }
                        if let min = game.minutes, min > 0 {
                            Text("•").foregroundColor(.secondary)
                            Text("\(min) min").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("\(year) (\(games.count) games)")
    }
}

// MARK: - Players Seen List
struct PlayersSeenListView: View {
    let players: [Player]
    let attendedKeys: Set<String>
    @Environment(\.modelContext) private var modelContext
    
    func timesSeenCount(for player: Player) -> Int {
        let pid = player.playerId
        let keys = Array(attendedKeys)
        let descriptor = FetchDescriptor<Game>(
            predicate: #Predicate<Game> { game in
                keys.contains(game.matchKey) &&
                (game.winner.playerId == pid || game.loser.playerId == pid)
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    var body: some View {
        List {
            ForEach(players) { player in
                NavigationLink(destination: PlayerAllYearsView(player: player)) {
                    HStack {
                        Text(flag(for: player.countryCode)).font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(player.name).font(.headline)
                            Text(player.countryCode).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(timesSeenCount(for: player))×")
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .navigationTitle("Players Seen (\(players.count))")
    }
}

// MARK: - Player All Years View
struct PlayerAllYearsView: View {
    let player: Player
    @Environment(\.modelContext) private var modelContext
    @State private var gamesByYear: [(year: String, count: Int)] = []
    
    var body: some View {
        List {
            ForEach(gamesByYear, id: \.year) { yearData in
                NavigationLink(destination: PlayerGamesView(player: player, selectedYear: yearData.year)) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue).font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(yearData.year).font(.headline)
                            Text("\(yearData.count) matches")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(player.name)
        .onAppear { loadYears() }
    }
    
    private func loadYears() {
        let pid = player.playerId
        let descriptor = FetchDescriptor<Game>(
            predicate: #Predicate<Game> { game in
                game.winner.playerId == pid || game.loser.playerId == pid
            }
        )
        guard let games = try? modelContext.fetch(descriptor) else { return }
        
        var dict: [String: Int] = [:]
        for game in games {
            dict[game.season, default: 0] += 1
        }
        gamesByYear = dict.keys.sorted(by: >).map { ($0, dict[$0]!) }
    }
}

// MARK: - Tournaments List
struct TournamentsListView: View {
    let tournaments: [(tournament: String, years: [String])]
    
    var body: some View {
        List {
            ForEach(tournaments, id: \.tournament) { data in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "trophy.fill").foregroundColor(.yellow)
                        Text(data.tournament).font(.body)
                    }
                    HStack(spacing: 6) {
                        ForEach(data.years, id: \.self) { year in
                            Text(year)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.leading, 28)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Tournaments (\(tournaments.count))")
    }
}
