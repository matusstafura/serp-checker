#!/bin/bash

# SEO Rankings Comparison Script
# Compares two ranking CSV files and shows position changes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

usage() {
    cat << EOF
Usage: $0 <old_rankings.csv> <new_rankings.csv>

Compares two ranking CSV files and shows:
  - Position improvements (green, ↑)
  - Position declines (red, ↓)
  - New keywords (blue, NEW)
  - Disappeared keywords (yellow, GONE)

Options:
  -h, --help          Show this help message
  -n, --min-change N  Only show changes >= N positions (default: 1)
  -s, --sort FIELD    Sort by: change|volume|position (default: change)
  -d, --domain DOMAIN Filter by specific domain
  -v, --verbose       Show all keywords including unchanged

Example:
  $0 rankings_2026-01-16.csv rankings_2026-01-23.csv
  $0 -n 3 -s volume old.csv new.csv  # Show changes >=3 positions, sort by volume
EOF
    exit 1
}

# Default options
MIN_CHANGE=1
SORT_BY="change"
FILTER_DOMAIN=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -n|--min-change)
            MIN_CHANGE="$2"
            shift 2
            ;;
        -s|--sort)
            SORT_BY="$2"
            shift 2
            ;;
        -d|--domain)
            FILTER_DOMAIN="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -ne 2 ]; then
    echo "Error: Please provide exactly two CSV files"
    usage
fi

OLD_FILE="$1"
NEW_FILE="$2"

if [ ! -f "$OLD_FILE" ]; then
    echo "Error: Old file '$OLD_FILE' not found"
    exit 1
fi

if [ ! -f "$NEW_FILE" ]; then
    echo "Error: New file '$NEW_FILE' not found"
    exit 1
fi

# Extract dates from filenames or files
OLD_DATE=$(grep -m1 "checked_at" "$OLD_FILE" | tail -1 | awk -F, '{print $NF}' | cut -d' ' -f1 || echo "unknown")
NEW_DATE=$(grep -m1 "checked_at" "$NEW_FILE" | tail -1 | awk -F, '{print $NF}' | cut -d' ' -f1 || echo "unknown")

echo -e "${BOLD}=== SEO Rankings Comparison ===${NC}"
echo -e "Old data: ${BLUE}${OLD_DATE}${NC}"
echo -e "New data: ${BLUE}${NEW_DATE}${NC}"
echo ""

# Create temporary files for processing
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

IMPROVEMENTS="$TMP_DIR/improvements.txt"
DECLINES="$TMP_DIR/declines.txt"
NEW_KW="$TMP_DIR/new.txt"
GONE_KW="$TMP_DIR/gone.txt"
UNCHANGED="$TMP_DIR/unchanged.txt"

# Process files with awk
awk -F, -v old_file="$OLD_FILE" -v min_change="$MIN_CHANGE" -v filter_domain="$FILTER_DOMAIN" -v verbose="$VERBOSE" '
BEGIN {
    # Read old file into array
    while ((getline < old_file) > 0) {
        if (NR == 1) continue  # Skip header
        key = $1 "|" $2 "|" $3  # domain|keyword|country
        old_pos[key] = $5  # position
        old_volume[key] = $4
        old_clicks[key] = $6
        old_impressions[key] = $7
    }
    close(old_file)
}
NR == 1 { next }  # Skip header in new file
{
    if (filter_domain != "" && $1 != filter_domain) next
    
    key = $1 "|" $2 "|" $3
    domain = $1
    keyword = $2
    country = $3
    volume = $4
    new_pos = $5
    clicks = $6
    impressions = $7
    
    if (key in old_pos) {
        old_p = old_pos[key]
        change = old_p - new_pos  # Positive = improvement (lower position number)
        abs_change = (change < 0) ? -change : change
        
        if (abs_change >= min_change || verbose == "true") {
            # Format: domain|keyword|country|volume|old_pos|new_pos|change|clicks|impressions
            output = domain "|" keyword "|" country "|" volume "|" old_p "|" new_pos "|" change "|" clicks "|" impressions
            
            if (change > 0) {
                print output > "'"$IMPROVEMENTS"'"
            } else if (change < 0) {
                print output > "'"$DECLINES"'"
            } else if (verbose == "true") {
                print output > "'"$UNCHANGED"'"
            }
        }
        delete old_pos[key]
    } else {
        # New keyword
        output = domain "|" keyword "|" country "|" volume "|" new_pos "|" clicks "|" impressions
        print output > "'"$NEW_KW"'"
    }
}
END {
    # Remaining old_pos entries are gone keywords
    for (key in old_pos) {
        if (filter_domain != "" && index(key, filter_domain) != 1) continue
        split(key, parts, "|")
        output = parts[1] "|" parts[2] "|" parts[3] "|" old_volume[key] "|" old_pos[key] "|" old_clicks[key] "|" old_impressions[key]
        print output > "'"$GONE_KW"'"
    }
}
' "$NEW_FILE"

# Helper function to sort results
sort_results() {
    local file=$1
    case $SORT_BY in
        volume)
            sort -t'|' -k4 -nr "$file"
            ;;
        position)
            sort -t'|' -k6 -n "$file"
            ;;
        change)
            sort -t'|' -k7 -nr "$file"
            ;;
        *)
            cat "$file"
            ;;
    esac
}

# Display improvements
if [ -f "$IMPROVEMENTS" ] && [ -s "$IMPROVEMENTS" ]; then
    echo -e "${GREEN}${BOLD}▲ IMPROVEMENTS (Position went up)${NC}"
    echo -e "${BOLD}$(printf '%-25s %-35s %-6s %8s %8s → %-8s %8s' "Domain" "Keyword" "Country" "Volume" "Old Pos" "New Pos" "Change")${NC}"
    echo "$(printf '%.0s-' {1..120})"
    
    sort_results "$IMPROVEMENTS" | while IFS='|' read -r domain keyword country volume old_pos new_pos change clicks impressions; do
        printf "${GREEN}%-25s %-35s %-6s %8s %8.2f → %-8.2f ↑ %+.2f${NC}\n" \
            "$domain" "$keyword" "$country" "$volume" "$old_pos" "$new_pos" "$change"
    done
    echo ""
fi

# Display declines
if [ -f "$DECLINES" ] && [ -s "$DECLINES" ]; then
    echo -e "${RED}${BOLD}▼ DECLINES (Position went down)${NC}"
    echo -e "${BOLD}$(printf '%-25s %-35s %-6s %8s %8s → %-8s %8s' "Domain" "Keyword" "Country" "Volume" "Old Pos" "New Pos" "Change")${NC}"
    echo "$(printf '%.0s-' {1..120})"
    
    sort_results "$DECLINES" | while IFS='|' read -r domain keyword country volume old_pos new_pos change clicks impressions; do
        printf "${RED}%-25s %-35s %-6s %8s %8.2f → %-8.2f ↓ %.2f${NC}\n" \
            "$domain" "$keyword" "$country" "$volume" "$old_pos" "$new_pos" "$change"
    done
    echo ""
fi

# Display new keywords
if [ -f "$NEW_KW" ] && [ -s "$NEW_KW" ]; then
    echo -e "${BLUE}${BOLD}★ NEW KEYWORDS${NC}"
    echo -e "${BOLD}$(printf '%-25s %-35s %-6s %8s %8s %8s %8s' "Domain" "Keyword" "Country" "Volume" "Position" "Clicks" "Impress.")${NC}"
    echo "$(printf '%.0s-' {1..120})"
    
    sort -t'|' -k4 -nr "$NEW_KW" | while IFS='|' read -r domain keyword country volume position clicks impressions; do
        printf "${BLUE}%-25s %-35s %-6s %8s %8.2f %8s %8s${NC}\n" \
            "$domain" "$keyword" "$country" "$volume" "$position" "$clicks" "$impressions"
    done
    echo ""
fi

# Display gone keywords
if [ -f "$GONE_KW" ] && [ -s "$GONE_KW" ]; then
    echo -e "${YELLOW}${BOLD}✗ DISAPPEARED KEYWORDS${NC}"
    echo -e "${BOLD}$(printf '%-25s %-35s %-6s %8s %8s %8s %8s' "Domain" "Keyword" "Country" "Volume" "Old Pos" "Clicks" "Impress.")${NC}"
    echo "$(printf '%.0s-' {1..120})"
    
    sort -t'|' -k4 -nr "$GONE_KW" | while IFS='|' read -r domain keyword country volume position clicks impressions; do
        printf "${YELLOW}%-25s %-35s %-6s %8s %8.2f %8s %8s${NC}\n" \
            "$domain" "$keyword" "$country" "$volume" "$position" "$clicks" "$impressions"
    done
    echo ""
fi

# Display unchanged (if verbose)
if [ "$VERBOSE" = true ] && [ -f "$UNCHANGED" ] && [ -s "$UNCHANGED" ]; then
    echo -e "${BOLD}= UNCHANGED${NC}"
    echo -e "${BOLD}$(printf '%-25s %-35s %-6s %8s %8s' "Domain" "Keyword" "Country" "Volume" "Position")${NC}"
    echo "$(printf '%.0s-' {1..120})"
    
    sort_results "$UNCHANGED" | while IFS='|' read -r domain keyword country volume old_pos new_pos change clicks impressions; do
        printf "%-25s %-35s %-6s %8s %8.2f\n" \
            "$domain" "$keyword" "$country" "$volume" "$new_pos"
    done
    echo ""
fi

# Summary statistics
echo -e "${BOLD}=== SUMMARY ===${NC}"

improvements_count=$([ -f "$IMPROVEMENTS" ] && wc -l < "$IMPROVEMENTS" || echo 0)
declines_count=$([ -f "$DECLINES" ] && wc -l < "$DECLINES" || echo 0)
new_count=$([ -f "$NEW_KW" ] && wc -l < "$NEW_KW" || echo 0)
gone_count=$([ -f "$GONE_KW" ] && wc -l < "$GONE_KW" || echo 0)

echo -e "${GREEN}Improvements:${NC}     $improvements_count keywords"
echo -e "${RED}Declines:${NC}         $declines_count keywords"
echo -e "${BLUE}New keywords:${NC}     $new_count keywords"
echo -e "${YELLOW}Disappeared:${NC}      $gone_count keywords"

# Calculate average position change for improvements/declines
if [ -f "$IMPROVEMENTS" ] && [ -s "$IMPROVEMENTS" ]; then
    avg_improvement=$(awk -F'|' '{sum+=$7; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$IMPROVEMENTS")
    echo -e "${GREEN}Avg improvement:${NC}  +${avg_improvement} positions"
fi

if [ -f "$DECLINES" ] && [ -s "$DECLINES" ]; then
    avg_decline=$(awk -F'|' '{sum+=$7; count++} END {if(count>0) printf "%.2f", -sum/count; else print "0"}' "$DECLINES")
    echo -e "${RED}Avg decline:${NC}      ${avg_decline} positions"
fi

echo ""
