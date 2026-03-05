# 🎾 TennisFanApp

A personal tennis tracking app for iOS. Search players, browse match history across 7 years, view detailed match statistics, and build your tennis passport by marking matches you've attended.

## Features

- **7 years of ATP data** (2020–2026) — 16,000+ matches
- **Rich match details** — scores, rankings, seeds, surface, duration, aces, break points
- **Player profiles** — height, backhand type, country, career stats per year
- **Tournament badges** — 🏆 Grand Slam, ⭐ Masters, 🎾 ATP 500
- **Expandable match stats** — tap 📊 to see aces, double faults, serve %, break points
- **Tennis Passport** — mark matches you attended, track players seen, tournaments visited
- **Attendance survives data reloads** — stored separately from match data
- **Auto-updating 2026 data** — downloads latest matches from GitHub on app launch
- **Fast** — targeted SwiftData queries, background data loading

## Data Sources

| Years | Source | Format |
|-------|--------|--------|
| 2020–2025 | [Jeff Sackmann / tennis_atp](https://github.com/JeffSackmann/tennis_atp) | CSV (bundled) |
| 2026 | Web scraper → GitHub | CSV (auto-downloaded) |
| Player profiles | ATP_Database.csv | CSV (bundled) |

## Architecture

```
Historical CSV (bundled) ──→ DataLoader ──→ SwiftData ──→ SwiftUI Views
2026 CSV (GitHub) ──→ DataUpdater ──→ SwiftData ──↗
Scraper (Python) ──→ 2026.csv ──→ GitHub repo
```

- **SwiftUI** + **SwiftData** (iOS 17+)
- 11 Swift files, ~2,000 lines
- Targeted database queries (no full table scans)
- Background data loading with progress indicator

## Updating 2026 Data

Run the scraper and push:

```bash
cd scraper
python3 scrape_atp.py --output ../2026.csv
cd ..
git add 2026.csv && git commit -m "Update 2026 data" && git push
```

The app downloads the updated file on next launch.

## Project Structure

```
TennisFanApp/
├── Models/
│   ├── Player.swift          # Player model (name, country, height, backhand)
│   ├── Game.swift            # Match model (35 fields — scores, stats, rankings)
│   └── Attendance.swift      # Attendance tracking (survives reloads)
├── Views/
│   ├── ContentView.swift     # Main screen — search, year pills, auto-update
│   ├── PlayerGamesView.swift # Player match list with stats
│   └── ProfileView.swift     # Tennis passport — attended games, players seen
├── TennisFanApp/
│   ├── DataLoader.swift      # CSV parser (handles 49 & 50 column formats)
│   ├── DataUpdater.swift     # Downloads 2026.csv from GitHub
│   └── TennisFanAppApp.swift # App entry point
├── Utilities.swift           # Country code → flag emoji
├── scraper/
│   ├── scrape_atp.py         # Python scraper for Tennis-Explorer
│   └── requirements.txt
├── .github/workflows/
│   └── scrape.yml            # GitHub Actions daily scraper
└── *.csv                     # Match data files (2020–2026)
```

## License

Match data from [Jeff Sackmann's tennis_atp](https://github.com/JeffSackmann/tennis_atp) under CC BY-NC-SA 4.0.
