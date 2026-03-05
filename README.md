# 🎾 TennisFanApp

A SwiftUI iOS app for tennis fans to track ATP matches and build their personal "tennis passport" by marking games they've attended.

## 📱 Features

### Core Functionality
- **Player Search** - Search through thousands of ATP players
- **Match History** - View complete match history for any player by season
- **Attendance Tracking** - Mark matches you've attended
- **Tennis Passport** - Personal profile showing:
  - Total games attended
  - Unique players seen (with frequency counts)
  - Tournaments attended (with years)
- **Statistics** - Win/loss records, match counts, and more

### Data Management
- **Automatic Updates** ✨ NEW! - Tap the refresh button to download latest match data from GitHub
- **Offline Support** - All data stored locally with SwiftData
- **Multi-Season** - Currently supports 2024 and 2025 seasons

## 🗂️ Project Structure

```
TennisFanApp/
├── Models/
│   ├── Player.swift          # Player data model
│   ├── Game.swift             # Match data model
│   └── UserAttendance.swift   # User attendance tracking
├── Views/
│   ├── ContentView.swift      # Main search interface
│   ├── PlayerGamesView.swift  # Player match history
│   ├── PlayerListView.swift   # Simple player list
│   └── ProfileView.swift      # Tennis passport/profile
├── ViewModels/
│   └── CSVUpdater.swift       # Automatic CSV update manager ✨ NEW!
├── TennisFanApp/
│   ├── DataLoader.swift       # CSV parsing and data loading
│   ├── TennisFanAppApp.swift  # App entry point
│   └── Utilities.swift        # Helper functions (country flags)
└── Data/
    ├── 2024.csv               # 2024 ATP match data (3,077 matches)
    ├── 2025.csv               # 2025 ATP match data (2,929 matches)
    └── ATP_Database.csv       # Player database
```

## 🔄 Automatic Data Updates (NEW!)

The app now includes automatic update functionality that downloads the latest ATP match data from Jeff Sackmann's GitHub repository.

### How It Works

1. **Tap the refresh button** (🔄) in the top-right corner
2. The app checks GitHub for updated CSV files
3. If new data is available, it downloads and replaces local files
4. The database is automatically reloaded with fresh data
5. Your attendance records are preserved

### Data Source

- **Repository**: [JeffSackmann/tennis_atp](https://github.com/JeffSackmann/tennis_atp)
- **Update Frequency**: Weekly (typically updated by Jeff Sackmann within 1-7 days after matches)
- **Data Quality**: Gold standard ATP match data with 50+ fields per match
- **Last Repository Update**: December 30, 2024

### Current Limitations

- **2025 Data**: Jeff Sackmann hasn't published the 2025 season file yet on GitHub
  - Your local 2025.csv has data through November 23, 2025 (Davis Cup Finals)
  - Once he publishes 2025 data, the auto-update will work for that season too
- **2024 Data**: ✅ Available on GitHub and can be auto-updated
- **Update Lag**: Typically 1-7 days after matches are played

### Technical Details

The `CSVUpdater` class handles:
- Downloading CSV files from GitHub
- Comparing file sizes to detect updates
- Saving to app's Documents directory
- Preserving user data during updates
- Graceful handling of missing files (404 errors)

## 📊 Data Statistics

- **Total Matches**: ~6,000 (3,077 from 2024 + 2,929 from 2025)
- **Players**: Hundreds of ATP players
- **Tournaments**: Grand Slams, ATP Tour, Davis Cup, and more
- **Data Fields**: 50+ per match (score, surface, round, date, stats, etc.)

## 🛠️ Technical Stack

- **Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Language**: Swift
- **Platform**: iOS
- **Architecture**: MVVM pattern

## 🚀 Getting Started

1. Open `TennisFanApp.xcodeproj` in Xcode
2. Build and run on iOS simulator or device
3. On first launch, tap the download button to load initial data
4. Search for players and start tracking your tennis journey!
5. Use the refresh button to get the latest match data

## 📅 Project Timeline

- **Started**: November 28, 2025
- **Last Major Update**: December 5, 2025 (UserAttendance model)
- **Auto-Update Feature Added**: February 10, 2026 ✨

## 🎯 Future Enhancements

### Planned Features
- [ ] Photo uploads for attended matches
- [ ] Notes/memories for each game
- [ ] Export tennis passport to PDF
- [ ] Social sharing
- [ ] Player favorites/watchlist
- [ ] Tournament calendar view
- [ ] Push notifications for favorite players
- [ ] WTA (women's tennis) support
- [ ] Live scores via API integration
- [ ] iCloud sync for attendance data

### Data Improvements
- [ ] Real-time API integration for current season
- [ ] Automatic background updates
- [ ] Smart data merging (preserve user data during updates)
- [ ] Historical data beyond 2024

## 📝 Notes

- The app currently uses bundled CSV files for initial data
- Updated CSVs are stored in the app's Documents directory
- User attendance data is preserved during updates
- The refresh button checks for updates for both 2024 and 2025 seasons
- A "Last updated" timestamp is shown at the bottom of the main screen

## 🙏 Credits

- **ATP Match Data**: [Jeff Sackmann's Tennis Abstract](https://github.com/JeffSackmann/tennis_atp)
- **Developer**: Alain Gendre
- **AI Assistant**: Goose (Block)

## 📄 License

This project uses data from Jeff Sackmann's tennis_atp repository. Please respect the data source's licensing terms.

---

**Last Updated**: February 10, 2026
