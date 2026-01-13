#!/bin/bash

# Usage: ./compare-rankings.sh rankings_2026-01-12.csv rankings_2026-01-13.csv

if [ $# -lt 2 ]; then
    echo "Usage: $0 <old_csv> <new_csv>"
    echo "Example: $0 rankings_2026-01-12.csv rankings_2026-01-13.csv"
    exit 1
fi

OLD_CSV="$1"
NEW_CSV="$2"

if [ ! -f "$OLD_CSV" ]; then
    echo "Error: $OLD_CSV not found"
    exit 1
fi

if [ ! -f "$NEW_CSV" ]; then
    echo "Error: $NEW_CSV not found"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           SERP Position Changes                           ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║ Old: $(basename $OLD_CSV)"
echo "║ New: $(basename $NEW_CSV)"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Create temp files with just keyword and position
awk -F',' 'NR>1 {print $2 "," $5}' "$OLD_CSV" | sort > /tmp/old_pos.txt
awk -F',' 'NR>1 {print $2 "," $5}' "$NEW_CSV" | sort > /tmp/new_pos.txt

echo "🔺 IMPROVEMENTS (Moved Up)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

join -t',' /tmp/old_pos.txt /tmp/new_pos.txt | awk -F',' '{
    keyword=$1
    old_pos=$2
    new_pos=$3
    diff=old_pos-new_pos
    if (diff > 0) {
        printf "✅ %-40s  %5.1f → %5.1f  (↑ %.1f)\n", keyword, old_pos, new_pos, diff
    }
}' | sort -t'↑' -k2 -rn

echo ""
echo "🔻 DECLINES (Moved Down)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

join -t',' /tmp/old_pos.txt /tmp/new_pos.txt | awk -F',' '{
    keyword=$1
    old_pos=$2
    new_pos=$3
    diff=old_pos-new_pos
    if (diff < 0) {
        printf "⚠️  %-40s  %5.1f → %5.1f  (↓ %.1f)\n", keyword, old_pos, new_pos, -diff
    }
}' | sort -t'↓' -k2 -rn

echo ""
echo "→  NO CHANGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

join -t',' /tmp/old_pos.txt /tmp/new_pos.txt | awk -F',' '{
    keyword=$1
    old_pos=$2
    new_pos=$3
    diff=old_pos-new_pos
    if (diff == 0) {
        printf "   %-40s  %5.1f (no change)\n", keyword, old_pos
    }
}'

echo ""
echo "🆕 NEW KEYWORDS (Not in old file)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

join -v2 -t',' /tmp/old_pos.txt /tmp/new_pos.txt | awk -F',' '{
    printf "🆕 %-40s  Position: %.1f\n", $1, $2
}'

echo ""
echo "❌ LOST RANKINGS (In old file, not in new)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

join -v1 -t',' /tmp/old_pos.txt /tmp/new_pos.txt | awk -F',' '{
    printf "❌ %-40s  Was: %.1f\n", $1, $2
}'

# Summary stats
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ SUMMARY                                                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"

IMPROVED=$(join -t',' /tmp/old_pos.txt /tmp/new_pos.txt | awk -F',' '$2>$3' | wc -l | tr -d ' ')
DECLINED=$(join -t',' /tmp/old_pos.txt /tmp/new_pos.txt | awk -F',' '$2<$3' | wc -l | tr -d ' ')
UNCHANGED=$(join -t',' /tmp/old_pos.txt /tmp/new_pos.txt | awk -F',' '$2==$3' | wc -l | tr -d ' ')
NEW_KW=$(join -v2 -t',' /tmp/old_pos.txt /tmp/new_pos.txt | wc -l | tr -d ' ')
LOST_KW=$(join -v1 -t',' /tmp/old_pos.txt /tmp/new_pos.txt | wc -l | tr -d ' ')

echo "✅ Improved:    $IMPROVED"
echo "⚠️  Declined:    $DECLINED"
echo "→  Unchanged:  $UNCHANGED"
echo "🆕 New:        $NEW_KW"
echo "❌ Lost:       $LOST_KW"
echo ""

# Cleanup
rm -f /tmp/old_pos.txt /tmp/new_pos.txt
