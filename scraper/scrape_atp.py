#!/usr/bin/env python3
"""
ATP Match Scraper for TennisFanApp
Scrapes Tennis-Explorer for current season results.
Outputs Sackmann-compatible CSV format (50 columns).

Usage:
    python3 scrape_atp.py                    # Scrape current year, all months so far
    python3 scrape_atp.py --year 2026        # Specific year
    python3 scrape_atp.py --month 2          # Specific month only
    python3 scrape_atp.py --output 2026.csv  # Custom output file

Designed to run daily via GitHub Actions or cron.
"""

import requests
from bs4 import BeautifulSoup
import csv
import re
import time
import argparse
import os
from datetime import datetime, date

BASE_URL = "https://www.tennisexplorer.com"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

# Sackmann CSV header (50 columns, 2024+ format)
CSV_HEADER = [
    "tourney_id", "tourney_name", "surface", "draw_size", "tourney_level",
    "indoor", "tourney_date", "match_num",
    "winner_id", "winner_seed", "winner_entry", "winner_name", "winner_hand",
    "winner_ht", "winner_ioc", "winner_age",
    "winner_rank", "winner_rank_points",
    "loser_id", "loser_seed", "loser_entry", "loser_name", "loser_hand",
    "loser_ht", "loser_ioc", "loser_age",
    "loser_rank", "loser_rank_points",
    "score", "best_of", "round", "minutes",
    "w_ace", "w_df", "w_svpt", "w_1stIn", "w_1stWon", "w_2ndWon",
    "w_SvGms", "w_bpSaved", "w_bpFaced",
    "l_ace", "l_df", "l_svpt", "l_1stIn", "l_1stWon", "l_2ndWon",
    "l_SvGms", "l_bpSaved", "l_bpFaced"
]

# Tournament level mapping
LEVEL_MAP = {
    "grand slam": "G",
    "masters": "M",
    "masters 1000": "M",
    "atp 500": "A",
    "atp 250": "250",
    "atp finals": "F",
    "davis cup": "D",
    "united cup": "D",
    "laver cup": "D",
    "olympics": "G",
    "olympic": "G",
}

# Known Grand Slams
GRAND_SLAMS = {"australian open", "roland garros", "wimbledon", "us open"}
MASTERS = {
    "indian wells", "miami", "monte carlo", "madrid", "rome",
    "canadian open", "cincinnati", "shanghai", "paris",
    "monte carlo masters", "madrid masters", "rome masters",
    "indian wells masters", "miami masters", "cincinnati masters",
    "shanghai masters", "paris masters", "canada masters",
}

# Surface mapping from tournament names/pages
SURFACE_HINTS = {
    "australian open": "Hard",
    "roland garros": "Clay",
    "wimbledon": "Grass",
    "us open": "Hard",
    "indian wells": "Hard",
    "miami": "Hard",
    "monte carlo": "Clay",
    "madrid": "Clay",
    "rome": "Clay",
    "canadian": "Hard",
    "cincinnati": "Hard",
    "shanghai": "Hard",
    "paris": "Hard",
}


def guess_tourney_level(name):
    """Guess tournament level from name."""
    name_lower = name.lower().strip()
    if any(gs in name_lower for gs in GRAND_SLAMS):
        return "G"
    if any(m in name_lower for m in MASTERS):
        return "M"
    if "challenger" in name_lower:
        return ""  # Skip challengers
    if "futures" in name_lower or "itf" in name_lower:
        return ""  # Skip futures/ITF
    if "utr" in name_lower:
        return ""  # Skip UTR events
    if "davis cup" in name_lower:
        return "D"
    if "united cup" in name_lower:
        return "D"
    if "atp finals" in name_lower or "tour finals" in name_lower:
        return "F"
    if "500" in name_lower:
        return "A"
    # Default to ATP 250
    return "250"


def guess_surface(name):
    """Guess surface from tournament name."""
    name_lower = name.lower()
    for hint, surface in SURFACE_HINTS.items():
        if hint in name_lower:
            return surface
    return ""


def guess_best_of(level):
    """Grand Slams are best of 5, everything else best of 3."""
    return 5 if level == "G" else 3


def make_tourney_id(year, name):
    """Create a tournament ID similar to Sackmann format."""
    slug = re.sub(r'[^a-z0-9]+', '-', name.lower().strip()).strip('-')
    return f"{year}-{slug}"


def fetch_page(url, delay=2):
    """Fetch a page with rate limiting."""
    time.sleep(delay)
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        return resp.text
    except Exception as e:
        print(f"  ⚠️ Failed to fetch {url}: {e}")
        return None


def scrape_tournament_detail(tourney_url):
    """Scrape a tournament page for surface and additional match details."""
    html = fetch_page(BASE_URL + tourney_url, delay=1)
    if not html:
        return {"surface": "", "matches": []}

    soup = BeautifulSoup(html, "html.parser")
    
    # Try to find surface from page text
    surface = ""
    page_text = soup.get_text().lower()
    if "hard" in page_text:
        surface = "Hard"
    elif "clay" in page_text:
        surface = "Clay"
    elif "grass" in page_text:
        surface = "Grass"
    elif "carpet" in page_text:
        surface = "Carpet"

    return {"surface": surface}


def scrape_monthly_results(year, month):
    """Scrape all ATP singles results for a given month."""
    url = f"{BASE_URL}/results/?type=atp-single&year={year}&month={month:02d}"
    print(f"  Fetching {year}-{month:02d}...")
    
    html = fetch_page(url)
    if not html:
        return []
    
    soup = BeautifulSoup(html, "html.parser")
    table = soup.find("table", class_="result")
    if not table:
        print(f"  No results table found for {year}-{month:02d}")
        return []
    
    rows = table.find_all("tr")
    matches = []
    current_tourney = None
    current_tourney_url = None
    current_surface = ""
    match_num = 0
    
    # Process rows in pairs (winner row + loser row)
    i = 0
    while i < len(rows):
        row = rows[i]
        cells = row.find_all("td")
        
        if not cells:
            i += 1
            continue
        
        # Check if this is a tournament header row
        tourney_cell = row.find("td", class_="t-name", colspan=True)
        if tourney_cell:
            link = tourney_cell.find("a")
            if link:
                current_tourney = link.get_text(strip=True)
                current_tourney_url = link.get("href", "")
                current_surface = guess_surface(current_tourney)
                match_num = 0
            i += 1
            continue
        
        # Check if this is a player row
        # Method 1: has "first time" cell (standard format)
        # Method 2: has t-name + result cells but no colspan (match row without time)
        p1_name_cell = row.find("td", class_="t-name")
        p1_result_cell = row.find("td", class_="result")
        
        if not p1_name_cell or p1_name_cell.get("colspan") or not p1_result_cell:
            i += 1
            continue
        
        # This is a player row — next row should be the opponent
        if i + 1 >= len(rows):
            i += 1
            continue
        
        row2 = rows[i + 1]
        
        p1_scores = row.find_all("td", class_="score")
        
        # Extract player 2 data
        p2_name_cell = row2.find("td", class_="t-name")
        p2_result_cell = row2.find("td", class_="result")
        p2_scores = row2.find_all("td", class_="score")
        
        if not p1_name_cell or not p2_name_cell or not p1_result_cell or not p2_result_cell:
            i += 2
            continue
        
        # Parse player names and seeds
        p1_link = p1_name_cell.find("a")
        p2_link = p2_name_cell.find("a")
        
        if not p1_link or not p2_link:
            i += 2
            continue
        
        p1_full = p1_name_cell.get_text(strip=True)
        p2_full = p2_name_cell.get_text(strip=True)
        p1_name = p1_link.get_text(strip=True)
        p2_name = p2_link.get_text(strip=True)
        p1_url = p1_link.get("href", "")
        p2_url = p2_link.get("href", "")
        
        # Extract seeds from parentheses
        p1_seed_match = re.search(r'\((\d+)\)', p1_full)
        p2_seed_match = re.search(r'\((\d+)\)', p2_full)
        p1_seed = p1_seed_match.group(1) if p1_seed_match else ""
        p2_seed = p2_seed_match.group(1) if p2_seed_match else ""
        
        # Extract player IDs from URLs
        p1_id = re.sub(r'[^a-z0-9-]', '', p1_url.replace('/player/', ''))
        p2_id = re.sub(r'[^a-z0-9-]', '', p2_url.replace('/player/', ''))
        
        # Determine winner/loser from result cells
        try:
            p1_sets = int(p1_result_cell.get_text(strip=True))
            p2_sets = int(p2_result_cell.get_text(strip=True))
        except (ValueError, AttributeError):
            i += 2
            continue
        
        # Build score string from set scores
        score_parts = []
        for s1, s2 in zip(p1_scores, p2_scores):
            s1_text = s1.get_text(strip=True).replace('\xa0', '')
            s2_text = s2.get_text(strip=True).replace('\xa0', '')
            if s1_text and s2_text and s1_text not in ('S', 'H', 'A') and s2_text not in ('S', 'H', 'A'):
                score_parts.append(f"{s1_text}-{s2_text}")
        
        score = " ".join(score_parts)
        if not score:
            i += 2
            continue
        
        # Skip if tournament is not ATP level
        if current_tourney:
            level = guess_tourney_level(current_tourney)
            if not level:  # Skip challengers, futures, UTR
                i += 2
                continue
        else:
            i += 2
            continue
        
        # Determine winner and loser
        if p1_sets > p2_sets:
            winner_name, loser_name = p1_name, p2_name
            winner_id, loser_id = p1_id, p2_id
            winner_seed, loser_seed = p1_seed, p2_seed
            # Score is already from winner perspective
        else:
            winner_name, loser_name = p2_name, p1_name
            winner_id, loser_id = p2_id, p1_id
            winner_seed, loser_seed = p2_seed, p1_seed
            # Flip score to winner perspective
            flipped = []
            for part in score_parts:
                if '-' in part:
                    a, b = part.split('-', 1)
                    flipped.append(f"{b}-{a}")
            score = " ".join(flipped)
        
        match_num += 1
        tourney_id = make_tourney_id(year, current_tourney)
        surface = current_surface
        best_of = guess_best_of(level)
        
        # Approximate tournament date as first of month
        tourney_date = f"{year}{month:02d}01"
        
        match = {
            "tourney_id": tourney_id,
            "tourney_name": current_tourney,
            "surface": surface,
            "draw_size": "",
            "tourney_level": level,
            "indoor": "",
            "tourney_date": tourney_date,
            "match_num": str(match_num),
            "winner_id": winner_id,
            "winner_seed": winner_seed,
            "winner_entry": "",
            "winner_name": winner_name,
            "winner_hand": "",
            "winner_ht": "",
            "winner_ioc": "",
            "winner_age": "",
            "winner_rank": "",
            "winner_rank_points": "",
            "loser_id": loser_id,
            "loser_seed": loser_seed,
            "loser_entry": "",
            "loser_name": loser_name,
            "loser_hand": "",
            "loser_ht": "",
            "loser_ioc": "",
            "loser_age": "",
            "loser_rank": "",
            "loser_rank_points": "",
            "score": score,
            "best_of": str(best_of),
            "round": "",  # Not available from monthly results page
            "minutes": "",
            "w_ace": "", "w_df": "", "w_svpt": "", "w_1stIn": "",
            "w_1stWon": "", "w_2ndWon": "", "w_SvGms": "",
            "w_bpSaved": "", "w_bpFaced": "",
            "l_ace": "", "l_df": "", "l_svpt": "", "l_1stIn": "",
            "l_1stWon": "", "l_2ndWon": "", "l_SvGms": "",
            "l_bpSaved": "", "l_bpFaced": "",
        }
        
        matches.append(match)
        i += 2
    
    return matches


def scrape_tournament_matches(tourney_url, tourney_name, year):
    """Scrape all matches from a tournament-specific page (draw/results)."""
    html = fetch_page(BASE_URL + tourney_url, delay=2)
    if not html:
        return []
    
    soup = BeautifulSoup(html, "html.parser")
    
    # Detect surface
    page_text = soup.get_text().lower()
    surface = ""
    if "grass" in page_text:
        surface = "Grass"
    elif "clay" in page_text:
        surface = "Clay"
    elif "hard" in page_text:
        surface = "Hard"
    elif "carpet" in page_text:
        surface = "Carpet"
    if not surface:
        surface = guess_surface(tourney_name)
    
    level = guess_tourney_level(tourney_name)
    best_of = guess_best_of(level)
    tourney_id = make_tourney_id(year, tourney_name)
    
    # Find all result tables
    tables = soup.find_all("table", class_="result")
    
    matches = []
    match_num = 0
    current_round = ""
    
    for table in tables:
        rows = table.find_all("tr")
        
        i = 0
        while i < len(rows):
            row = rows[i]
            
            # Check for round header
            round_cell = row.find("th", class_="first")
            if round_cell:
                round_text = round_cell.get_text(strip=True)
                # Map round names
                round_map = {
                    "1. round": "R128", "2. round": "R64", "3. round": "R32",
                    "round of 16": "R16", "quarterfinal": "QF",
                    "semifinal": "SF", "final": "F",
                    "1st round": "R128", "2nd round": "R64", "3rd round": "R32",
                    "round of 32": "R32", "round of 64": "R64",
                }
                current_round = round_map.get(round_text.lower(), round_text)
                i += 1
                continue
            
            # Check for round in td with title attribute
            round_td = row.find("td", attrs={"title": True, "style": lambda s: s and "round" in str(s)})
            if round_td:
                round_text = round_td.get("title", "")
                round_map = {
                    "1. round": "R128", "2. round": "R64", "3. round": "R32",
                    "round of 16": "R16", "quarterfinal": "QF",
                    "semifinal": "SF", "final": "F",
                }
                current_round = round_map.get(round_text.lower(), round_text)
            
            # Look for match rows (player name cells)
            name_cells = row.find_all("td", class_="t-name")
            if len(name_cells) >= 2:
                # This row has two players — it's a draw-style row
                p1_cell, p2_cell = name_cells[0], name_cells[1]
                p1_link = p1_cell.find("a")
                p2_link = p2_cell.find("a")
                
                if p1_link and p2_link:
                    p1_name = p1_link.get_text(strip=True)
                    p2_name = p2_link.get_text(strip=True)
                    p1_full = p1_cell.get_text(strip=True)
                    p2_full = p2_cell.get_text(strip=True)
                    p1_url = p1_link.get("href", "")
                    p2_url = p2_link.get("href", "")
                    
                    p1_seed = ""
                    p2_seed = ""
                    seed_m = re.search(r'\((\d+)\)', p1_full)
                    if seed_m: p1_seed = seed_m.group(1)
                    seed_m = re.search(r'\((\d+)\)', p2_full)
                    if seed_m: p2_seed = seed_m.group(1)
                    
                    p1_id = re.sub(r'[^a-z0-9-]', '', p1_url.replace('/player/', ''))
                    p2_id = re.sub(r'[^a-z0-9-]', '', p2_url.replace('/player/', ''))
                    
                    # Find score - look for result cells
                    result_cells = row.find_all("td", class_="result")
                    score_cells = row.find_all("td", class_="score")
                    
                    # Determine winner from bold or result
                    # On draw pages, the winner's name is often bold
                    p1_bold = p1_cell.find("strong") or p1_cell.find("b")
                    p2_bold = p2_cell.find("strong") or p2_cell.find("b")
                    
                    # Try to get score from cells
                    score = ""
                    if score_cells:
                        parts = []
                        for sc in score_cells:
                            t = sc.get_text(strip=True).replace('\xa0', '')
                            if t and t not in ('S', 'H', 'A', '1', '2', '3', '4', '5'):
                                parts.append(t)
                        if parts:
                            # Scores come in pairs
                            score_pairs = []
                            for j in range(0, len(parts) - 1, 2):
                                score_pairs.append(f"{parts[j]}-{parts[j+1]}")
                            score = " ".join(score_pairs)
                    
                    if not score:
                        i += 1
                        continue
                    
                    # Determine winner
                    if p1_bold:
                        winner_name, loser_name = p1_name, p2_name
                        winner_id, loser_id = p1_id, p2_id
                        winner_seed, loser_seed = p1_seed, p2_seed
                    elif p2_bold:
                        winner_name, loser_name = p2_name, p1_name
                        winner_id, loser_id = p2_id, p1_id
                        winner_seed, loser_seed = p2_seed, p1_seed
                    else:
                        # Can't determine winner, skip
                        i += 1
                        continue
                    
                    match_num += 1
                    tourney_date = f"{year}0101"  # Will be refined
                    
                    match = {k: "" for k in CSV_HEADER}
                    match.update({
                        "tourney_id": tourney_id,
                        "tourney_name": tourney_name,
                        "surface": surface,
                        "tourney_level": level,
                        "tourney_date": tourney_date,
                        "match_num": str(match_num),
                        "winner_id": winner_id,
                        "winner_seed": winner_seed,
                        "winner_name": winner_name,
                        "loser_id": loser_id,
                        "loser_seed": loser_seed,
                        "loser_name": loser_name,
                        "score": score,
                        "best_of": str(best_of),
                        "round": current_round,
                    })
                    matches.append(match)
                
                i += 1
                continue
            
            # Single-player row (results page format) — handled by monthly scraper
            i += 1
    
    return matches


def enrich_with_tournament_details(matches, year):
    """Fetch tournament pages to get surface, round info, and additional matches."""
    tourneys = {}
    for m in matches:
        tid = m["tourney_id"]
        if tid not in tourneys:
            tourneys[tid] = {"name": m["tourney_name"], "matches": []}
        tourneys[tid]["matches"].append(m)
    
    all_new_matches = []
    
    for tid, data in tourneys.items():
        name = data["name"]
        slug = re.sub(r'[^a-z0-9]+', '-', name.lower().strip()).strip('-')
        tourney_url = f"/{slug}/{year}/atp-men/"
        
        print(f"  Enriching {name}...")
        detail = scrape_tournament_detail(tourney_url)
        
        # Update surface for existing matches
        if detail["surface"]:
            for m in data["matches"]:
                if not m["surface"]:
                    m["surface"] = detail["surface"]
        
        # Try to get more matches from tournament page
        tourney_matches = scrape_tournament_matches(tourney_url, name, year)
        if tourney_matches:
            print(f"    Found {len(tourney_matches)} matches from tournament page")
            all_new_matches.extend(tourney_matches)
    
    return all_new_matches


def write_csv(matches, filename):
    """Write matches to Sackmann-format CSV."""
    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_HEADER)
        writer.writeheader()
        for m in matches:
            writer.writerow(m)
    print(f"\n✅ Wrote {len(matches)} matches to {filename}")


def main():
    parser = argparse.ArgumentParser(description="Scrape ATP match results from Tennis-Explorer")
    parser.add_argument("--year", type=int, default=date.today().year, help="Year to scrape")
    parser.add_argument("--month", type=int, default=0, help="Specific month (0 = all months so far)")
    parser.add_argument("--output", type=str, default="", help="Output CSV filename")
    parser.add_argument("--no-enrich", action="store_true", help="Skip tournament detail enrichment")
    args = parser.parse_args()
    
    year = args.year
    output = args.output or f"{year}.csv"
    
    if args.month > 0:
        months = [args.month]
    else:
        # Scrape all months up to current month
        if year == date.today().year:
            months = list(range(1, date.today().month + 1))
        else:
            months = list(range(1, 13))
    
    print(f"🎾 ATP Scraper — {year}")
    print(f"   Months: {months}")
    print(f"   Output: {output}")
    print()
    
    all_matches = []
    
    for month in months:
        matches = scrape_monthly_results(year, month)
        print(f"  → {len(matches)} ATP matches found")
        all_matches.extend(matches)
    
    print(f"\n📊 Total: {len(all_matches)} matches scraped")
    
    # Enrich with tournament details (surface + extra matches from tournament pages)
    if not args.no_enrich and all_matches:
        print("\n🔍 Enriching with tournament details...")
        extra_matches = enrich_with_tournament_details(all_matches, year)
        if extra_matches:
            # Deduplicate by winner+loser+score
            existing_sigs = set()
            for m in all_matches:
                sig = f"{m['winner_name']}_{m['loser_name']}_{m['score']}"
                existing_sigs.add(sig)
            
            added = 0
            for m in extra_matches:
                sig = f"{m['winner_name']}_{m['loser_name']}_{m['score']}"
                if sig not in existing_sigs:
                    all_matches.append(m)
                    existing_sigs.add(sig)
                    added += 1
            print(f"  Added {added} new matches from tournament pages")
    
    # Merge with existing file if it exists
    if os.path.exists(output):
        print(f"\n📂 Merging with existing {output}...")
        existing_keys = set()
        existing_matches = []
        with open(output, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                key = f"{row['tourney_id']}_{row['match_num']}"
                existing_keys.add(key)
                existing_matches.append(row)
        
        new_count = 0
        for m in all_matches:
            key = f"{m['tourney_id']}_{m['match_num']}"
            if key not in existing_keys:
                existing_matches.append(m)
                new_count += 1
        
        print(f"  Existing: {len(existing_keys)} matches")
        print(f"  New: {new_count} matches")
        all_matches = existing_matches
    
    write_csv(all_matches, output)
    
    # Summary
    tourneys = set(m["tourney_name"] for m in all_matches)
    print(f"\n📋 Summary:")
    print(f"   Matches: {len(all_matches)}")
    print(f"   Tournaments: {len(tourneys)}")
    for t in sorted(tourneys):
        count = sum(1 for m in all_matches if m["tourney_name"] == t)
        print(f"     {t}: {count} matches")


if __name__ == "__main__":
    main()
