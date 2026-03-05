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
    @Query(sort: \Player.name) private var players: [Player]
    @State private var searchText = ""
    @State private var selectedYear = "2025"
    @State private var availableYears: [String] = []
    @State private var loadingStatus = ""
    @State private var lastUpdate: Date? = DataUpdater.lastUpdateDate()
    @State private var updateStatus = ""
    @State private var hasCheckedForUpdates = false
    
    var filteredPlayers: [Player] {
        guard !searchText.isEmpty else { return [] }
        return players.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

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
                    if filteredPlayers.isEmpty {
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
                        List(filteredPlayers) { player in
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
                if availableYears.isEmpty && !players.isEmpty {
                    loadAvailableYears()
                }
            }
            .task {
                // Wait for data to be available, then check for updates
                // This runs once when the view first appears
                while availableYears.isEmpty {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                    if !players.isEmpty && availableYears.isEmpty {
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
            // Still check for 2026 updates on subsequent launches
            await checkForUpdates()
            return
        }
        
        // Load on background thread
        loadingStatus = "Preparing..."
        
        await Task.detached {
            await MainActor.run {
                DataLoader.loadData(modelContext: modelContext)
            }
        }.value
        
        loadingStatus = "Ready!"
        loadAvailableYears()
        
        // Check for 2026 updates after initial load
        await checkForUpdates()
    }
    
    private func checkForUpdates() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        
        updateStatus = "Checking for updates..."
        print("🔄 checkForUpdates started")
        
        let hasUpdate = await DataUpdater.checkForUpdate()
        print("🔄 hasUpdate = \(hasUpdate)")
        
        if hasUpdate {
            updateStatus = "Updating 2026 data..."
            DataUpdater.reload2026(modelContext: modelContext)
            loadAvailableYears()
            lastUpdate = DataUpdater.lastUpdateDate()
            updateStatus = "✅ Updated!"
            print("🔄 Update complete, years: \(availableYears)")
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            updateStatus = ""
        } else {
            // Even if no update, make sure 2026 is in available years
            loadAvailableYears()
            lastUpdate = DataUpdater.lastUpdateDate()
            updateStatus = ""
            print("🔄 No update needed, years: \(availableYears)")
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
