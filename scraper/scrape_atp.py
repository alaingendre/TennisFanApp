#!/usr/bin/env python3
"""
ATP Match Scraper for TennisFanApp
Scrapes Tennis-Explorer tournament pages for current season results.
Outputs Sackmann-compatible CSV format (50 columns).

Usage:
    python3 scrape_atp.py                    # Scrape current year
    python3 scrape_atp.py --year 2026        # Specific year
    python3 scrape_atp.py --output 2026.csv  # Custom output file
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
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
}

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

GRAND_SLAMS = {"australian open", "roland garros", "wimbledon", "us open"}
MASTERS = {
    "indian wells", "miami", "monte carlo", "madrid", "rome",
    "canadian open", "cincinnati", "shanghai", "paris",
}

SURFACE_HINTS = {
    "australian open": "Hard", "roland garros": "Clay", "wimbledon": "Grass",
    "us open": "Hard", "indian wells": "Hard", "miami": "Hard",
    "monte carlo": "Clay", "madrid": "Clay", "rome": "Clay",
    "canadian": "Hard", "cincinnati": "Hard", "shanghai": "Hard", "paris": "Hard",
}

ROUND_MAP = {
    "1. round": "R128", "2. round": "R64", "3. round": "R32",
    "round of 16": "R16", "quarterfinal": "QF", "semifinal": "SF", "final": "F",
    "1r": "R128", "2r": "R64", "3r": "R32", "r16": "R16",
    "qf": "QF", "sf": "SF", "f": "F",
    "1st round": "R128", "2nd round": "R64", "3rd round": "R32",
}


def guess_level(name):
    n = name.lower().strip()
    if any(gs in n for gs in GRAND_SLAMS): return "G"
    if any(m in n for m in MASTERS): return "M"
    if "challenger" in n or "futures" in n or "itf" in n or "utr" in n: return ""
    if "davis cup" in n or "united cup" in n: return "D"
    if "atp finals" in n: return "F"
    return "250"


def guess_surface(name):
    for hint, surface in SURFACE_HINTS.items():
        if hint in name.lower(): return surface
    return ""


def fetch(url, delay=2):
    time.sleep(delay)
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        return resp.text
    except Exception as e:
        print(f"    ⚠️ Failed: {url} — {e}")
        return None


def discover_tournaments(year):
    """Find all ATP tournament URLs for a given year."""
    tournaments = []
    seen_urls = set()
    
    # Known major tournaments that might not appear on monthly results pages
    KNOWN_TOURNAMENTS = [
        {"slug": "australian-open", "name": "Australian Open", "level": "G"},
        {"slug": "roland-garros", "name": "Roland Garros", "level": "G"},
        {"slug": "wimbledon", "name": "Wimbledon", "level": "G"},
        {"slug": "us-open", "name": "US Open", "level": "G"},
        {"slug": "indian-wells", "name": "Indian Wells", "level": "M"},
        {"slug": "miami", "name": "Miami", "level": "M"},
        {"slug": "monte-carlo", "name": "Monte Carlo", "level": "M"},
        {"slug": "madrid", "name": "Madrid", "level": "M"},
        {"slug": "rome", "name": "Rome", "level": "M"},
        {"slug": "canadian-open", "name": "Canadian Open", "level": "M"},
        {"slug": "cincinnati", "name": "Cincinnati", "level": "M"},
        {"slug": "shanghai", "name": "Shanghai", "level": "M"},
        {"slug": "paris", "name": "Paris", "level": "M"},
        {"slug": "united-cup", "name": "United Cup", "level": "D"},
        {"slug": "davis-cup", "name": "Davis Cup", "level": "D"},
        {"slug": "atp-finals", "name": "ATP Finals", "level": "F"},
    ]
    
    # Add known tournaments first
    for t in KNOWN_TOURNAMENTS:
        url = f"/{t['slug']}/{year}/atp-men/"
        if url not in seen_urls:
            seen_urls.add(url)
            tournaments.append({
                'url': url,
                'slug': t['slug'],
                'name': t['name'],
                'level': t['level'],
            })
    
    # Also scan monthly results pages for additional tournaments
    for month in range(1, 13):
        if year == date.today().year and month > date.today().month:
            break
        
        html = fetch(f"{BASE_URL}/results/?type=atp-single&year={year}&month={month:02d}", delay=1)
        if not html:
            continue
        
        urls = re.findall(r'href="(/[^/]+/' + str(year) + r'/atp-men/)"', html)
        for url in urls:
            if url in seen_urls:
                continue
            
            slug = url.split('/')[1]
            name_guess = slug.replace('-', ' ').title()
            
            level = guess_level(name_guess)
            if not level:
                continue
            
            seen_urls.add(url)
            tournaments.append({
                'url': url,
                'slug': slug,
                'name': name_guess,
                'level': level,
            })
    
    return tournaments


def scrape_tournament(tourney_url, year):
    """Scrape all completed matches from a tournament page."""
    html = fetch(BASE_URL + tourney_url)
    if not html:
        return [], "", ""
    
    soup = BeautifulSoup(html, 'html.parser')
    
    # Detect surface
    page_text = soup.get_text().lower()
    surface = ""
    for s in ['grass', 'clay', 'hard', 'carpet']:
        if s in page_text:
            surface = s.capitalize()
            break
    
    # Get tournament name from page title
    title_tag = soup.find('title')
    tourney_name = ""
    if title_tag:
        # Title format: "Tournament Name 2026 - Tennis Explorer" or "Tennis Explorer: Tournament Name 2026"
        raw_title = title_tag.get_text()
        tourney_name = raw_title.split(' - Tennis Explorer')[0].strip()
        tourney_name = tourney_name.replace('Tennis Explorer: ', '').replace(f' {year}', '').strip()
    
    # Find the completed results table (Table 1 — has dates and scores)
    tables = soup.find_all('table', class_='result')
    
    matches = []
    
    for table in tables:
        rows = table.find_all('tr')
        if not rows:
            continue
        
        # Check if this is a results table (has "S" score header and date entries)
        header = rows[0]
        header_text = header.get_text()
        if 'Start' in header_text and 'Round' in header_text and ('S' in header_text or '1' in header_text):
            # This is a results/schedule table
            pass
        else:
            continue
        
        i = 1  # Skip header row
        while i < len(rows):
            row = rows[i]
            
            # Look for player 1 row (has "first" class cell with date/time)
            first_cell = row.find('td', class_='first')
            p1_name_cell = row.find('td', class_='t-name')
            p1_result_cell = row.find('td', class_='result')
            
            if not first_cell or not p1_name_cell or not p1_result_cell:
                i += 1
                continue
            
            # Get date from first cell (format: "05.03.03:55" or "today, 06:05")
            first_text = first_cell.get_text(strip=True)
            match_date_str = ""
            date_match = re.match(r'(\d{2})\.(\d{2})\.', first_text)
            if date_match:
                day, month = date_match.group(1), date_match.group(2)
                match_date_str = f"{year}{month}{day}"
            
            # Get round from round cell
            round_cell = row.find('td', attrs={'title': True})
            match_round = ""
            if round_cell:
                round_title = round_cell.get('title', '').lower()
                match_round = ROUND_MAP.get(round_title, round_cell.get_text(strip=True))
            if not match_round:
                # Try the text content
                for cell in row.find_all('td'):
                    text = cell.get_text(strip=True)
                    if text in ('1R', '2R', '3R', 'R16', 'QF', 'SF', 'F'):
                        match_round = ROUND_MAP.get(text.lower(), text)
                        break
            
            # Get player 2 from next row
            if i + 1 >= len(rows):
                i += 1
                continue
            
            row2 = rows[i + 1]
            p2_name_cell = row2.find('td', class_='t-name')
            p2_result_cell = row2.find('td', class_='result')
            
            if not p2_name_cell or not p2_result_cell:
                i += 2
                continue
            
            # Extract player names
            p1_link = p1_name_cell.find('a')
            p2_link = p2_name_cell.find('a')
            if not p1_link or not p2_link:
                i += 2
                continue
            
            p1_name = p1_link.get_text(strip=True)
            p2_name = p2_link.get_text(strip=True)
            p1_url = p1_link.get('href', '')
            p2_url = p2_link.get('href', '')
            
            # Extract seeds
            p1_full = p1_name_cell.get_text(strip=True)
            p2_full = p2_name_cell.get_text(strip=True)
            p1_seed = ""
            p2_seed = ""
            sm = re.search(r'\((\d+)\)', p1_full)
            if sm: p1_seed = sm.group(1)
            sm = re.search(r'\((\d+)\)', p2_full)
            if sm: p2_seed = sm.group(1)
            
            # Player IDs from URLs
            p1_id = re.sub(r'[^a-z0-9-]', '', p1_url.replace('/player/', ''))
            p2_id = re.sub(r'[^a-z0-9-]', '', p2_url.replace('/player/', ''))
            
            # Get sets won
            try:
                p1_sets = int(p1_result_cell.get_text(strip=True))
                p2_sets = int(p2_result_cell.get_text(strip=True))
            except (ValueError, AttributeError):
                i += 2
                continue
            
            # Skip if match not completed (both 0, or scheduled)
            if p1_sets == 0 and p2_sets == 0:
                i += 2
                continue
            
            # Build score
            p1_scores = [s.get_text(strip=True).replace('\xa0', '') for s in row.find_all('td', class_='score')]
            p2_scores = [s.get_text(strip=True).replace('\xa0', '') for s in row2.find_all('td', class_='score')]
            
            score_parts = []
            for s1, s2 in zip(p1_scores, p2_scores):
                if s1 and s2 and s1 not in ('S', 'H', 'A') and s2 not in ('S', 'H', 'A'):
                    score_parts.append(f"{s1}-{s2}")
            
            if not score_parts:
                i += 2
                continue
            
            # Determine winner/loser
            if p1_sets > p2_sets:
                winner_name, loser_name = p1_name, p2_name
                winner_id, loser_id = p1_id, p2_id
                winner_seed, loser_seed = p1_seed, p2_seed
                score = " ".join(score_parts)
            else:
                winner_name, loser_name = p2_name, p1_name
                winner_id, loser_id = p2_id, p1_id
                winner_seed, loser_seed = p2_seed, p1_seed
                flipped = []
                for part in score_parts:
                    if '-' in part:
                        a, b = part.split('-', 1)
                        flipped.append(f"{b}-{a}")
                score = " ".join(flipped)
            
            match = {k: "" for k in CSV_HEADER}
            match.update({
                "tourney_name": tourney_name,
                "tourney_date": match_date_str,
                "match_num": str(len(matches) + 1),
                "winner_id": winner_id,
                "winner_seed": winner_seed,
                "winner_name": winner_name,
                "loser_id": loser_id,
                "loser_seed": loser_seed,
                "loser_name": loser_name,
                "score": score,
                "round": match_round,
            })
            matches.append(match)
            i += 2
    
    return matches, tourney_name, surface


def main():
    parser = argparse.ArgumentParser(description="Scrape ATP results from Tennis-Explorer")
    parser.add_argument("--year", type=int, default=date.today().year)
    parser.add_argument("--output", type=str, default="")
    args = parser.parse_args()
    
    year = args.year
    output = args.output or f"{year}.csv"
    
    print(f"🎾 ATP Scraper v2 — {year}")
    print(f"   Output: {output}")
    print()
    
    # Step 1: Discover tournaments
    print("📋 Discovering tournaments...")
    tournaments = discover_tournaments(year)
    print(f"   Found {len(tournaments)} ATP tournaments")
    for t in tournaments:
        print(f"     {t['name']} ({t['level']})")
    print()
    
    # Step 2: Scrape each tournament
    all_matches = []
    
    for t in tournaments:
        print(f"🎾 Scraping {t['name']}...")
        matches, name, surface = scrape_tournament(t['url'], year)
        
        if name:
            t['name'] = name
        if not surface:
            surface = guess_surface(t['name'])
        
        level = guess_level(t['name'])
        if not level:
            continue
        
        tourney_id = f"{year}-{t['slug']}"
        best_of = 5 if level == "G" else 3
        
        for m in matches:
            m['tourney_id'] = tourney_id
            if not m['tourney_name']:
                m['tourney_name'] = t['name']
            m['surface'] = surface
            m['tourney_level'] = level
            m['best_of'] = str(best_of)
            # Use tournament date if match date not available
            if not m['tourney_date']:
                m['tourney_date'] = f"{year}0101"
        
        all_matches.extend(matches)
        print(f"   → {len(matches)} completed matches")
    
    # Deduplicate by winner+loser+score
    seen = set()
    unique = []
    for m in all_matches:
        sig = f"{m['winner_name']}_{m['loser_name']}_{m['score']}"
        if sig not in seen:
            seen.add(sig)
            unique.append(m)
    
    all_matches = unique
    
    # Renumber match_num per tournament
    by_tourney = {}
    for m in all_matches:
        tid = m['tourney_id']
        if tid not in by_tourney:
            by_tourney[tid] = []
        by_tourney[tid].append(m)
    
    for tid, matches in by_tourney.items():
        for i, m in enumerate(matches, 1):
            m['match_num'] = str(i)
    
    # Write CSV
    with open(output, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_HEADER)
        writer.writeheader()
        for m in all_matches:
            writer.writerow(m)
    
    print(f"\n✅ Wrote {len(all_matches)} matches to {output}")
    
    # Summary
    print(f"\n📋 Summary:")
    for tid in sorted(by_tourney.keys()):
        matches = by_tourney[tid]
        name = matches[0]['tourney_name']
        rounds = set(m['round'] for m in matches if m['round'])
        print(f"   {name}: {len(matches)} matches {sorted(rounds) if rounds else ''}")


if __name__ == "__main__":
    main()
