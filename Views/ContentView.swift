//
//  ContentView.swift
//  TennisFanApp
//
//  Created by Alain Gendre on 11/28/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedYear = "2025"
    @State private var availableYears: [String] = []
    @State private var loadingStatus = ""
    @State private var isLoading = true
    @State private var hasCheckedForUpdates = false
    @State private var searchResults: [Player] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Loading state
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading match data...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if !loadingStatus.isEmpty {
                            Text(loadingStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Year pills (show as soon as any data is loaded)
                if !availableYears.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(availableYears, id: \.self) { year in
                                Button(action: { selectedYear = year }) {
                                    Text(year)
                                        .font(.subheadline)
                                        .fontWeight(selectedYear == year ? .bold : .regular)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedYear == year ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(selectedYear == year ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                
                // Search results or empty state (only when not loading)
                if !isLoading {
                    if !searchText.isEmpty {
                        if searchResults.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No players found")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(searchResults) { player in
                                NavigationLink(destination: PlayerGamesView(player: player, selectedYear: selectedYear)) {
                                    HStack {
                                        Text(flag(for: player.countryCode))
                                            .font(.title2)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(player.name)
                                                .font(.headline)
                                            Text(player.countryCode)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    } else {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 80))
                                .foregroundColor(.blue.opacity(0.3))
                            Text("Search for a player")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Start typing a player name to see results")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Tennis Fan")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search player name")
            .onChange(of: searchText) { _, newValue in
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if searchText == newValue {
                        performSearch(newValue)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        // Check if already loaded
        let countDescriptor = FetchDescriptor<Game>()
        if let count = try? modelContext.fetchCount(countDescriptor), count > 0 {
            refreshYears()
            isLoading = false
            await checkForUpdates()
            return
        }
        
        // Fresh load — show spinner
        isLoading = true
        let playerDB = DataLoader.loadPlayerDatabasePublic()
        var playerDict: [String: Player] = [:]
        
        // Load most recent years first
        let allSeasons = ["2025", "2024", "2026", "2023", "2022", "2021", "2020"]
        
        for (i, season) in allSeasons.enumerated() {
            loadingStatus = "\(season)..."
            
            if season == "2026" {
                DataLoader.load2026Public(modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
            } else {
                DataLoader.loadSeasonPublic(from: season, modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
            }
            try? modelContext.save()
            
            // After first 3 seasons (2025, 2024, 2026), show the UI
            if i == 2 {
                refreshYears()
                isLoading = false
            }
            
            // Yield to let UI render
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Final refresh with all years
        refreshYears()
        loadingStatus = ""
        
        await checkForUpdates()
    }
    
    // MARK: - Search
    
    private func performSearch(_ query: String) {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        let q = query
        var descriptor = FetchDescriptor<Player>(
            predicate: #Predicate<Player> { player in
                player.name.localizedStandardContains(q)
            },
            sortBy: [SortDescriptor(\Player.name)]
        )
        descriptor.fetchLimit = 20
        searchResults = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Year Management
    
    private func refreshYears() {
        // Use a lightweight query — just fetch season strings, not full Game objects
        let descriptor = FetchDescriptor<Game>()
        if let games = try? modelContext.fetch(descriptor) {
            let years = Set(games.map { $0.season })
            let sorted = Array(years).sorted(by: >)
            if sorted != availableYears {
                availableYears = sorted
                if let first = sorted.first, !sorted.contains(selectedYear) {
                    selectedYear = first
                }
            }
        }
    }
    
    // MARK: - Updates
    
    private func checkForUpdates() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        
        let hasUpdate = await DataUpdater.checkForUpdate()
        
        if hasUpdate {
            DataUpdater.reload2026(modelContext: modelContext)
            refreshYears()
        }
    }
}
