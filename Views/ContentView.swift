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
    @State private var lastUpdate: Date? = DataUpdater.lastUpdateDate()
    @State private var updateStatus = ""
    @State private var hasCheckedForUpdates = false
    @State private var searchResults: [Player] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if availableYears.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading match data...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("\(loadingStatus)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await loadDataInBackground()
                    }
                } else {
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
            .navigationTitle("Tennis Fan")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search player name")
            .onChange(of: searchText) { _, newValue in
                // Debounce: only search after user stops typing briefly
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    if searchText == newValue { // Only if text hasn't changed
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
            .overlay(alignment: .bottom) {
                if !availableYears.isEmpty && !searchText.isEmpty == false {
                    VStack(spacing: 4) {
                        if !updateStatus.isEmpty {
                            Text(updateStatus)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let date = lastUpdate {
                            Text("2026 data updated: \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.bottom, 8)
                }
            }
            .onAppear {
                if availableYears.isEmpty {
                    loadAvailableYears()
                }
            }
            .task {
                // Wait for data to be available, then check for updates
                // This runs once when the view first appears
                while availableYears.isEmpty {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                    if availableYears.isEmpty {
                        loadAvailableYears()
                    }
                }
                await checkForUpdates()
            }
        }
    }
    
    private func loadDataInBackground() async {
        // Check if already loaded
        let descriptor = FetchDescriptor<Player>()
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            loadAvailableYears()
            await checkForUpdates()
            return
        }
        
        let playerDB = DataLoader.loadPlayerDatabasePublic()
        var playerDict: [String: Player] = [:]
        
        // Phase 1: Load recent years first (fast, gets UI responsive)
        loadingStatus = "Loading recent matches..."
        DataLoader.loadSeasonPublic(from: "2025", modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
        DataLoader.loadSeasonPublic(from: "2024", modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
        DataLoader.load2026Public(modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
        try? modelContext.save()
        
        // Show UI immediately with 2024-2026
        loadAvailableYears()
        loadingStatus = ""
        
        // Phase 2: Load older years in background (user can already use the app)
        for season in ["2023", "2022", "2021", "2020"] {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms yield
            DataLoader.loadSeasonPublic(from: season, modelContext: modelContext, playerDict: &playerDict, playerDB: playerDB)
            try? modelContext.save()
            loadAvailableYears() // Update year pills as each year loads
        }
        
        await checkForUpdates()
    }
    
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
    
    private func checkForUpdates() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        
        updateStatus = "Checking for updates..."
        
        let hasUpdate = await DataUpdater.checkForUpdate()
        
        if hasUpdate {
            updateStatus = "Updating 2026 data..."
            DataUpdater.reload2026(modelContext: modelContext)
            loadAvailableYears()
            lastUpdate = DataUpdater.lastUpdateDate()
            updateStatus = "✅ Updated!"
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            updateStatus = ""
        } else {
            // Even if no update, make sure 2026 is in available years
            loadAvailableYears()
            lastUpdate = DataUpdater.lastUpdateDate()
            updateStatus = ""
        }
    }
    
    private func loadAvailableYears() {
        let descriptor = FetchDescriptor<Game>()
        if let games = try? modelContext.fetch(descriptor) {
            let years = Set(games.map { $0.season })
            availableYears = Array(years).sorted(by: >)
            if let first = availableYears.first {
                selectedYear = first
            }
        }
    }
}
