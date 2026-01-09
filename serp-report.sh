#!/bin/bash

DB="./serp_rankings.db"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if DB exists
if [ ! -f "$DB" ]; then
    echo "Error: Database not found at $DB"
    exit 1
fi

# Function to show menu
show_menu() {
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║     SERP Ranking Reports                  ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""
    echo "1)  Latest rankings (all keywords)"
    echo "2)  Position changes (with trends)"
    echo "3)  Best performers (top positions)"
    echo "4)  Worst performers (needs improvement)"
    echo "5)  Keyword trends (specific keyword)"
    echo "6)  Store overview (all stores)"
    echo "7)  API quota usage"
    echo "8)  Keywords with no data"
    echo "9)  Export to CSV"
    echo "0)  Exit"
    echo ""
    read -p "Select option: " choice
}

# 1. Latest rankings
latest_rankings() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "Latest Rankings (Most Recent Check)"
    echo "════════════════════════════════════════════"
    
    sqlite3 -header -column "$DB" <<EOF
SELECT 
    SUBSTR(domain, 11) as store,
    keyword,
    PRINTF('%.1f', position) as pos,
    impressions as impr,
    clicks,
    PRINTF('%.1f%%', ctr * 100) as ctr,
    DATE(checked_at) as date
FROM rankings
WHERE checked_at = (SELECT MAX(checked_at) FROM rankings)
ORDER BY position ASC;
EOF
}

# 2. Position changes with trends
position_changes() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "Position Changes (vs Previous Check)"
    echo "════════════════════════════════════════════"
    
    sqlite3 -header -column "$DB" <<EOF
WITH latest AS (
    SELECT domain, keyword, country, position, checked_at,
           ROW_NUMBER() OVER (PARTITION BY domain, keyword, country ORDER BY checked_at DESC) as rn
    FROM rankings
),
current_check AS (
    SELECT domain, keyword, country, position as current_pos, checked_at as current_date
    FROM latest WHERE rn = 1
),
previous_check AS (
    SELECT domain, keyword, country, position as previous_pos, checked_at as previous_date
    FROM latest WHERE rn = 2
)
SELECT 
    SUBSTR(c.domain, 11) as store,
    c.keyword,
    PRINTF('%.1f', c.current_pos) as current,
    PRINTF('%.1f', p.previous_pos) as previous,
    CASE 
        WHEN p.previous_pos IS NULL THEN 'NEW'
        WHEN c.current_pos < p.previous_pos THEN '↑ ' || PRINTF('%.1f', p.previous_pos - c.current_pos)
        WHEN c.current_pos > p.previous_pos THEN '↓ ' || PRINTF('%.1f', c.current_pos - p.previous_pos)
        ELSE '→ 0'
    END as change,
    DATE(c.current_date) as date
FROM current_check c
LEFT JOIN previous_check p 
    ON c.domain = p.domain 
    AND c.keyword = p.keyword 
    AND c.country = p.country
ORDER BY 
    CASE 
        WHEN p.previous_pos IS NULL THEN 999
        ELSE ABS(c.current_pos - p.previous_pos)
    END DESC;
EOF
}

# 3. Best performers
best_performers() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "Top 10 Best Performing Keywords"
    echo "════════════════════════════════════════════"
    
    sqlite3 -header -column "$DB" <<EOF
SELECT 
    SUBSTR(domain, 11) as store,
    keyword,
    PRINTF('%.1f', position) as pos,
    impressions,
    clicks,
    PRINTF('%.1f%%', ctr * 100) as ctr
FROM rankings
WHERE checked_at = (SELECT MAX(checked_at) FROM rankings)
ORDER BY position ASC
LIMIT 10;
EOF
}

# 4. Worst performers
worst_performers() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "Keywords Needing Improvement (Position > 10)"
    echo "════════════════════════════════════════════"
    
    sqlite3 -header -column "$DB" <<EOF
SELECT 
    SUBSTR(domain, 11) as store,
    keyword,
    PRINTF('%.1f', position) as pos,
    impressions,
    clicks
FROM rankings
WHERE checked_at = (SELECT MAX(checked_at) FROM rankings)
  AND position > 10
ORDER BY position DESC;
EOF
}

# 5. Keyword trends
keyword_trends() {
    echo ""
    read -p "Enter keyword to analyze: " kw
    
    echo ""
    echo "════════════════════════════════════════════"
    echo "Trend for: $kw"
    echo "════════════════════════════════════════════"
    
    sqlite3 -header -column "$DB" <<EOF
SELECT 
    DATE(checked_at) as date,
    SUBSTR(domain, 11) as store,
    PRINTF('%.1f', position) as pos,
    impressions,
    clicks,
    PRINTF('%.1f%%', ctr * 100) as ctr
FROM rankings
WHERE keyword LIKE '%$kw%'
ORDER BY checked_at DESC
LIMIT 20;
EOF
}

# 6. Store overview
store_overview() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "Overview by Store (Latest Check)"
    echo "════════════════════════════════════════════"
    
    sqlite3 -header -column "$DB" <<EOF
SELECT 
    SUBSTR(domain, 11) as store,
    COUNT(*) as keywords,
    PRINTF('%.1f', AVG(position)) as avg_pos,
    PRINTF('%.1f', MIN(position)) as best_pos,
    PRINTF('%.1f', MAX(position)) as worst_pos,
    SUM(impressions) as total_impr,
    SUM(clicks) as total_clicks,
    PRINTF('%.1f%%', AVG(ctr) * 100) as avg_ctr
FROM rankings
WHERE checked_at = (SELECT MAX(checked_at) FROM rankings)
GROUP BY domain
ORDER BY AVG(position) ASC;
EOF
}

# 7. API quota usage
api_quota() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "API Quota Usage (Last 7 Days)"
    echo "════════════════════════════════════════════"
    
    sqlite3 -header -column "$DB" <<EOF
SELECT 
    date,
    api_calls as calls,
    successful_calls as success,
    failed_calls as failed,
    PRINTF('%.1f%%', 100.0 * api_calls / 1200) as quota_used,
    (1200 - api_calls) as remaining
FROM api_usage 
WHERE date >= date('now', '-7 days')
ORDER BY date DESC;
EOF

    echo ""
    echo "Daily limit: 1,200 API calls"
}

# 8. Keywords with no data
no_data_keywords() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "Keywords Not Ranking (Latest Check)"
    echo "════════════════════════════════════════════"
    echo ""
    echo "Note: These keywords were checked but returned no data"
    echo "This means your site didn't appear in search results"
    echo "or had zero impressions during the period."
    echo ""
    
    # This requires tracking failed keywords in your Go code
    # For now, show keywords not in latest batch
    echo "Run your Go checker with -v flag to see which keywords had no data"
}

# 9. Export to CSV
export_csv() {
    echo ""
    read -p "Export filename (default: rankings_export.csv): " filename
    filename=${filename:-rankings_export.csv}
    
    sqlite3 -header -csv "$DB" <<EOF > "$filename"
SELECT 
    domain,
    keyword,
    country,
    position,
    clicks,
    impressions,
    ctr,
    period_start,
    period_end,
    checked_at
FROM rankings
ORDER BY checked_at DESC, domain, keyword;
EOF
    
    echo "✅ Exported to: $filename"
}

# Main loop
while true; do
    show_menu
    
    case $choice in
        1) latest_rankings ;;
        2) position_changes ;;
        3) best_performers ;;
        4) worst_performers ;;
        5) keyword_trends ;;
        6) store_overview ;;
        7) api_quota ;;
        8) no_data_keywords ;;
        9) export_csv ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
