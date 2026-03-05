//
//  Utilities.swift
//  TennisFanApp
//
//  Created by Alain Gendre on 12/1/25.
//

import Foundation

// Convert country code (e.g., "ESP", "USA") to flag emoji
func flag(for countryCode: String) -> String {
    // Country codes are typically 3-letter ISO codes
    // Convert to Unicode flag emoji by using regional indicator symbols
    let code = countryCode.uppercased()
    
    // Handle special cases and common codes
    let specialCases: [String: String] = [
        "ENG": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", // England
        "SCO": "🏴󠁧󠁢󠁳󠁣󠁴󠁿", // Scotland
        "WAL": "🏴󠁧󠁢󠁷󠁬󠁳󠁿", // Wales
    ]
    
    if let specialFlag = specialCases[code] {
        return specialFlag
    }
    
    // For standard ISO 3166-1 alpha-3 codes, convert to alpha-2
    // This is a simplified mapping for common tennis countries
    let codeMapping: [String: String] = [
        "ARG": "AR", "AUS": "AU", "AUT": "AT", "BEL": "BE", "BEN": "BJ",
        "BIH": "BA", "BRA": "BR", "BUL": "BG", "CAN": "CA", "CHI": "CL",
        "CHN": "CN", "COL": "CO", "CRO": "HR", "CYP": "CY", "CZE": "CZ",
        "DEN": "DK", "ECU": "EC", "EGY": "EG", "ESA": "SV", "ESP": "ES",
        "FIN": "FI", "FRA": "FR", "GBR": "GB", "GEO": "GE", "GER": "DE",
        "GRE": "GR", "HKG": "HK", "HUN": "HU", "IND": "IN", "IRL": "IE",
        "ISR": "IL", "ITA": "IT", "JAM": "JM", "JOR": "JO", "JPN": "JP",
        "KAZ": "KZ", "KOR": "KR", "KSA": "SA", "LAT": "LV", "LBN": "LB",
        "LTU": "LT", "LUX": "LU", "MEX": "MX", "MNE": "ME", "MON": "MC",
        "NAM": "NA", "NED": "NL", "NGR": "NG", "NOR": "NO", "NZL": "NZ",
        "PAK": "PK", "PAR": "PY", "PER": "PE", "POL": "PL", "POR": "PT",
        "ROU": "RO", "RSA": "ZA", "RUS": "RU", "SLO": "SI", "SRB": "RS",
        "SUI": "CH", "SVK": "SK", "SWE": "SE", "TPE": "TW", "TUN": "TN",
        "TUR": "TR", "UKR": "UA", "URU": "UY", "USA": "US", "VEN": "VE"
    ]
    
    guard let alpha2 = codeMapping[code] else {
        return "🏳️" // Default flag if country not found
    }
    
    // Convert 2-letter code to flag emoji
    // Each letter maps to a regional indicator symbol (🇦 = U+1F1E6, 🇧 = U+1F1E7, etc.)
    let base: UInt32 = 127397 // Offset for regional indicator symbols
    var flagString = ""
    for scalar in alpha2.unicodeScalars {
        if let regionalIndicator = UnicodeScalar(base + scalar.value) {
            flagString.append(String(regionalIndicator))
        }
    }
    
    return flagString.isEmpty ? "🏳️" : flagString
}
