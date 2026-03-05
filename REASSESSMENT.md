# 🎾 TennisFanApp — Honest Reassessment

**Date:** February 10, 2026

---

## 1. What You Actually Have

### The App (1,334 lines of Swift)

| File | Lines | Purpose |
|------|-------|---------|
| DataLoader.swift | 197 | Parses Sackmann CSV files into SwiftData |
| ContentView.swift | 243 | Search bar + year picker + player list |
| PlayerGamesView.swift | 253 | Match list for one player in one year |
| ProfileView.swift | 427 | "Tennis Passport" — attended games, players seen, tournaments |
| PlayerListView.swift | 17 | Simple list (barely used) |
| Utilities.swift | 61 | Country code → flag emoji |
| Player.swift | 28 | SwiftData model: id, name, hand, countryCode |
| Game.swift | 36 | SwiftData model: tournament, surface, round, date, score, season, winner, loser, userAttended |
| UserAttendance.swift | 33 | Composite key helper (not actively used — Game.userAttended does the job) |
| TennisFanAppApp.swift | 21 | App entry point |
| Item.swift | 18 | Unused Xcode template file |
| CSVUpdater.swift | 163 | Not in Xcode build — dead code |
| CSVUpdater 2.swift | 163 | Duplicate of above — dead code |

**Verdict:** ~1,100 lines of working code. The rest is dead weight.

### The Data

| File | Matches | In Xcode Build? |
|------|---------|-----------------|
| 2024.csv | 3,076 | ✅ Yes |
| 2025.csv | 2,928 | ✅ Yes |
| 2020.csv | 1,462 | ❌ No (wrong filename when added) |
| 2021.csv | 2,733 | ❌ No |
| 2022.csv | 2,917 | ❌ No |
| 2023.csv | 2,986 | ❌ No |
| ATP_Database.csv | 7,649 players | ❌ Not used by code at all |

**Verdict:** App currently runs with **2024 + 2025 only** (6,004 matches). The 2020-2023 files are downloaded but not loadable. ATP_Database.csv is completely ignored.

### The Documentation

18 markdown/text files totalling ~7,500 lines. That's **5× more documentation than code**. Most of it is session notes, checklists, and repeated summaries — not useful going forward.

---

## 2. What's Actually Wrong

### Architecture Problems

1. **No live data path.** The app is a static CSV viewer. There is no mechanism to get new matches after the CSV files were bundled. The CSVUpdater was never integrated.

2. **Full table scan on every view.** `PlayerGamesView` and `ProfileView` use `@Query private var allGames: [Game]` and then loop through *every game in the database* with Swift `for` loops. With 6,000 matches this is sluggish. With 16,000+ it will be painful.

3. **Year picker is hardcoded.** `let availableYears = ["2025", "2024"]` — even if you load 2020-2023, the picker won't show them.

4. **CSV columns are 74% wasted.** You parse 50 columns but only use 13. Rankings, seeds, ages, heights, match stats (aces, double faults, break points, minutes) are all thrown away. These are the most interesting data for a tennis fan.

5. **No data source for 2026.** Jeff Sackmann hasn't published 2025 or 2026 files. His repo hasn't been updated since Dec 30, 2024. You need a different source for current-season data.

6. **SwiftData model is too thin.** `Player` has 4 fields. `Game` has 8 fields + 2 relationships. The CSV has 50 columns of rich data per match and the ATP_Database has 12 columns per player (birthdate, height, weight, coaches, backhand type). None of this is captured.

7. **Attendance tracking is fragile.** `Game.userAttended` is a boolean on the Game model. If you ever reload data (which the refresh button does), all attendance flags are wiped because `reloadData()` calls `modelContext.delete(model: Game.self)`.

### Xcode Project Problems

8. **CSV files with wrong names.** 2020-2023 were added as "2020 2.csv" etc. DataLoader looks for "2020.csv". They don't load.

9. **Dead files.** `Item.swift` (unused template), two identical `CSVUpdater.swift` files (neither in build), `UserAttendance.swift` (not actively used).

10. **No Git history.** One commit from Nov 28, 2025. Two months of changes are uncommitted.

---

## 3. The Real Data Landscape for Men's Tennis

### Historical Data (Pre-2025): SOLVED

**Jeff Sackmann's `tennis_atp` GitHub repo** is the gold standard:
- Coverage: 1968–2024, every ATP main-draw match
- Format: One CSV per year, 50 columns, consistent schema
- Cost: Free (CC BY-NC-SA 4.0)
- Quality: ⭐⭐⭐⭐⭐
- URL: `https://github.com/JeffSackmann/tennis_atp`

You already have 2020-2025 downloaded. For deeper history, just download more year files — same format, same parser.

**Recommendation:** Use Sackmann CSVs for all historical data. Bundle them in the app. This is the right approach and you already have it working for 2024-2025.

### Current Season Data (2026): THE REAL PROBLEM

| Source | Has 2026? | Cost | Format | Update Speed | Reliability |
|--------|-----------|------|--------|-------------|-------------|
| Jeff Sackmann GitHub | ❌ No | Free | CSV | Months lag | High when available |
| API-Sports | ❌ No tennis API | — | — | — | — |
| SofaScore | ⚠️ Unofficial internal API | Free | JSON | Real-time | Can break anytime |
| Sportradar | ✅ Yes | $10,000+/yr | JSON | Real-time | Enterprise-grade |
| RapidAPI "Ultimate Tennis" | ⚠️ Unverified | $10/mo | JSON | Unknown | Unknown |
| Tennis-Data.co.uk | ⚠️ Partial | Free | CSV/Excel | Weekly | Medium |
| ATP Tour website | ✅ Yes | Free (scrape) | HTML | Real-time | Fragile |
| Flashscore | ✅ Yes | Free (scrape) | HTML | Real-time | Fragile |
| Wikipedia | ⚠️ Partial | Free (legal) | HTML | Days lag | Medium |

**Honest truth:** There is no cheap, reliable, legal, real-time API for ATP match results aimed at individual developers. The tennis data ecosystem is far behind football/basketball.

### Best Realistic Strategy

**Tier 1 — Historical (2020-2025): Sackmann CSV bundles**
- Already done. Just fix the Xcode file naming issue.
- One-time cost: $0. Maintenance: zero.

**Tier 2 — Current season (2026+): Lightweight scraper**
- Scrape a results page (Flashscore or Tennis-Explorer) once per day
- Output to the same CSV format as Sackmann
- Run as a Python script on your Mac (cron) or a free GitHub Action
- App downloads the CSV from a simple hosting location (GitHub Pages, your own repo, or a small server)

**Tier 3 — Near-live (optional future): SofaScore internal API**
- Unofficial but comprehensive
- Good for "last 24 hours" updates
- Accept that it may break; fall back to scraper

This hybrid gives you:
- ✅ Complete history (free, reliable, bundled)
- ✅ Current season within 24 hours (free, automated)
- ✅ No ongoing subscription costs
- ✅ No dependency on a single fragile API

---

## 4. Recommended Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────┐
│                    DATA SOURCES                      │
├──────────────────────┬──────────────────────────────┤
│  HISTORICAL          │  CURRENT SEASON              │
│  Sackmann CSVs       │  Daily scraper → CSV         │
│  Bundled in app      │  Hosted on GitHub Pages      │
│  2020-2025           │  2026+                       │
└──────────┬───────────┴──────────────┬───────────────┘
           │                          │
           ▼                          ▼
┌──────────────────┐    ┌─────────────────────────────┐
│ Bundle.main      │    │ URLSession download          │
│ (first launch)   │    │ (daily check on app open)    │
└──────────┬───────┘    └──────────────┬──────────────┘
           │                           │
           ▼                           ▼
┌─────────────────────────────────────────────────────┐
│              UNIFIED CSV PARSER                      │
│         (same Sackmann 50-column format)             │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                   SwiftData                          │
│  Player  (enriched: rank, age, height, seed)         │
│  Match   (enriched: stats, minutes, best_of)         │
│  Attendance (separate model, survives reloads)       │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                   SwiftUI Views                      │
│  Search → Player → Matches → Stats → Passport       │
└─────────────────────────────────────────────────────┘
```

### Key Design Decisions

**1. Same CSV format everywhere.**
The scraper outputs Sackmann-format CSV. This means one parser handles everything — historical bundles and live updates. No JSON conversion, no API client, no format mapping.

**2. Attendance is stored separately.**
Move `userAttended` out of `Game` and into a standalone `Attendance` model keyed by a stable match identifier (e.g., `tourney_id + match_num`). This survives data reloads.

**3. Richer models.**
Capture all 50 columns. Players get rankings, seeds, ages. Matches get stats, duration, best-of. This unlocks features like "show me all 5-set matches I attended" or "players ranked in top 10 I've seen."

**4. Incremental updates.**
Don't wipe and reload. Check what's already in the database, only insert new matches. Use `tourney_id + match_num` as a unique key.

**5. Dynamic year picker.**
Query distinct seasons from the database instead of hardcoding.

---

## 5. Concrete Implementation Plan

### Phase 1: Fix What's Broken (2 hours)

**Goal:** App runs correctly with 2024-2025 data on your iPhone.

- [ ] Delete from Xcode: all "?" CSV references, `CSVUpdater 2.swift`, `Item.swift`
- [ ] Delete from disk: all duplicate CSVs (`2020 2.csv`, `2020 3.csv`, etc.)
- [ ] Keep CSVUpdater.swift on disk but don't add to build yet
- [ ] Fix `availableYears` — derive from data:
  ```swift
  var availableYears: [String] {
      Array(Set(allGames.map { $0.season })).sorted(by: >)
  }
  ```
- [ ] Commit everything to Git with meaningful message
- [ ] Build and test on iPhone with 2024-2025

### Phase 2: Enrich the Models (3 hours)

**Goal:** Capture all 50 CSV columns. Protect attendance data.

- [ ] Expand `Player` model:
  ```swift
  @Model final class Player {
      @Attribute(.unique) var playerId: String
      var name: String
      var hand: String
      var countryCode: String
      var height: Int?          // cm
  }
  ```

- [ ] Expand `Game` → rename to `Match`:
  ```swift
  @Model final class Match {
      @Attribute(.unique) var matchKey: String  // tourney_id + match_num
      var tourneyId: String
      var tournamentName: String
      var surface: String
      var indoorOutdoor: String
      var tourneyLevel: String   // G=Grand Slam, M=Masters, A=ATP500, etc.
      var drawSize: Int
      var round: String
      var bestOf: Int
      var matchDate: Date
      var score: String
      var minutes: Int?
      var season: String
      var winner: Player
      var loser: Player
      var winnerSeed: Int?
      var winnerRank: Int?
      var winnerAge: Double?
      var loserSeed: Int?
      var loserRank: Int?
      var loserAge: Double?
      // Match stats
      var wAce: Int?
      var wDf: Int?
      var wBpSaved: Int?
      var wBpFaced: Int?
      var lAce: Int?
      var lDf: Int?
      var lBpSaved: Int?
      var lBpFaced: Int?
  }
  ```

- [ ] Create separate `Attendance` model:
  ```swift
  @Model final class Attendance {
      @Attribute(.unique) var matchKey: String
      var attendedDate: Date
  }
  ```

- [ ] Update DataLoader to parse all 50 columns
- [ ] Update DataLoader to use `matchKey` for deduplication (incremental loads)
- [ ] Update views to use new field names

### Phase 3: Add Historical Years (1 hour)

**Goal:** 2020-2025 all loading correctly.

- [ ] Clean up CSV files on disk (remove all duplicates)
- [ ] Add 2020.csv through 2023.csv to Xcode via command line:
  ```bash
  # We can script the pbxproj edit or use xcodebuild
  ```
- [ ] Test: year picker shows 2020-2025 automatically
- [ ] Test: search "Djokovic" shows matches across all years
- [ ] Commit to Git

### Phase 4: Build the Scraper (4 hours)

**Goal:** Automated daily CSV generation for 2026 season.

- [ ] Create Python scraper targeting Flashscore or Tennis-Explorer
- [ ] Output format: identical to Sackmann CSV (50 columns, same headers)
- [ ] Fields the scraper can realistically get:
  - tourney_name, surface, tourney_date, round, score ✅
  - winner_name, loser_name, winner_ioc, loser_ioc ✅
  - winner_rank, loser_rank ✅ (usually shown)
  - winner_seed, loser_seed ✅ (for seeded players)
  - minutes ⚠️ (sometimes available)
  - Detailed stats (aces, DFs, etc.) ⚠️ (only for major tournaments)
- [ ] Host output CSV on GitHub Pages (free) or a GitHub repo
- [ ] Schedule with cron (Mac) or GitHub Actions (free, runs daily)
- [ ] Test: scraper produces valid CSV for recent tournaments

### Phase 5: Connect App to Live Data (3 hours)

**Goal:** App checks for new 2026 data on launch.

- [ ] On app launch, check hosted CSV URL for updates
- [ ] Compare with local data (last match date or file hash)
- [ ] If newer, download and parse incrementally (don't wipe)
- [ ] Show "Updated through [date]" in UI
- [ ] Graceful offline handling (use cached data)
- [ ] Add pull-to-refresh gesture

### Phase 6: Polish (ongoing)

- [ ] Use `tourneyLevel` to show tournament tier badges (🏆 Grand Slam, ⭐ Masters, etc.)
- [ ] Show match stats when available (aces, break points)
- [ ] Show player rankings at time of match
- [ ] Add match duration display
- [ ] App icon
- [ ] Onboarding screen
- [ ] Git tags for versions

---

## 6. The Scraper — Detailed Design

### Why Flashscore?

| Factor | ATP Tour | Flashscore | Tennis-Explorer |
|--------|----------|------------|-----------------|
| Data completeness | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Ease of scraping | ⭐ (heavy JS) | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| Anti-bot measures | Aggressive | Moderate | Light |
| Update speed | Real-time | Real-time | Same day |
| Legal risk | High | Medium | Medium |

**Tennis-Explorer is the best target** — clean HTML, light anti-bot, good data, same-day updates.

### Scraper Architecture

```
┌──────────────────────────────────────────────┐
│  scraper.py (runs daily via cron/GH Action)  │
│                                               │
│  1. Fetch tournament results pages            │
│  2. Parse HTML with BeautifulSoup             │
│  3. Map to Sackmann CSV columns               │
│  4. Merge with existing 2026.csv              │
│  5. Commit updated CSV to GitHub repo         │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  GitHub repo (or GitHub Pages)                │
│  raw.githubusercontent.com/.../2026.csv       │
│  Free hosting, version controlled             │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  TennisFanApp                                 │
│  Downloads 2026.csv on launch                 │
│  Parses with same DataLoader                  │
│  Inserts new matches incrementally            │
└──────────────────────────────────────────────┘
```

### GitHub Actions Schedule (Free)

```yaml
# .github/workflows/scrape.yml
name: Scrape ATP Results
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM UTC
  workflow_dispatch:       # Manual trigger

jobs:
  scrape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install requests beautifulsoup4
      - run: python scraper.py
      - run: |
          git config user.name "ATP Scraper"
          git config user.email "scraper@example.com"
          git add 2026.csv
          git diff --cached --quiet || git commit -m "Update 2026 data $(date +%Y-%m-%d)"
          git push
```

**Cost:** $0 (GitHub Actions free tier: 2,000 minutes/month. This uses ~2 minutes/day = 60/month.)

---

## 7. What to Delete

### Files to Remove

| File | Reason |
|------|--------|
| `Item.swift` | Unused Xcode template |
| `CSVUpdater 2.swift` | Duplicate |
| `CSVUpdater.swift` | Never integrated; replace with simpler download logic |
| `UserAttendance.swift` | Redundant with `Game.userAttended`; replace with new `Attendance` model |
| All `*.md` files (18) | Session notes, not project docs. Keep only README.md |
| All `*.txt` files | Session notes |
| `2020 2.csv`, `2020 3.csv`, etc. | Duplicates with wrong names |

### Keep

| File | Reason |
|------|--------|
| All files in `Models/`, `Views/` | Core app code |
| `DataLoader.swift` | Core data loading (will be enhanced) |
| `TennisFanAppApp.swift` | App entry point |
| `Utilities.swift` | Flag emoji converter |
| `2020.csv` through `2025.csv` | Historical data |
| `ATP_Database.csv` | Player metadata (to be integrated) |
| `README.md` | Keep one, rewrite it |

---

## 8. Effort Estimate

| Phase | Hours | Result |
|-------|-------|--------|
| 1. Fix what's broken | 2 | App runs on iPhone with 2024-2025 |
| 2. Enrich models | 3 | All 50 CSV columns captured |
| 3. Add historical years | 1 | 2020-2025 working (16K matches) |
| 4. Build scraper | 4 | Daily 2026 CSV generation |
| 5. Connect live data | 3 | App auto-updates on launch |
| 6. Polish | ongoing | UI improvements, stats views |
| **Total to MVP** | **~13 hours** | **Full 2020-2026 with daily updates** |

---

## 9. Summary

### What's Good
- The core concept (tennis passport / attendance tracker) is unique and compelling
- SwiftUI + SwiftData is the right tech stack
- Sackmann CSV data is excellent for historical coverage
- The app works on your iPhone right now (with 2024-2025)

### What Needs to Change
- Stop adding documentation files and start fixing code
- Enrich the data models to use all 50 CSV columns
- Separate attendance from match data so reloads don't wipe it
- Build a simple scraper for 2026 data instead of searching for a perfect API (it doesn't exist)
- Make the year picker dynamic
- Add incremental data loading instead of wipe-and-reload

### The Path Forward
1. **Fix the basics** (2 hours) — get it running clean
2. **Enrich the models** (3 hours) — use the data you already have
3. **Build the scraper** (4 hours) — solve the 2026 problem for real
4. **Connect it** (3 hours) — app updates itself daily
5. **Ship it** — you have a unique app that no one else has built

The tennis data ecosystem doesn't have a clean API solution for individual developers. Accept that reality and build around it with the scraper approach. It's free, it's automated, and it produces data in the exact format your app already understands.
