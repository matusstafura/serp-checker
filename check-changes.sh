#!/bin/bash

# Automatically compare the two most recent CSV files

FILES=($(ls -t rankings_*.csv 2>/dev/null))

if [ ${#FILES[@]} -lt 2 ]; then
    echo "Error: Need at least 2 ranking CSV files to compare"
    echo "Found: ${#FILES[@]} file(s)"
    exit 1
fi

OLD="${FILES[1]}"
NEW="${FILES[0]}"

echo "Comparing:"
echo "  Old: $OLD"
echo "  New: $NEW"
echo ""

./compare-rankings.sh "$OLD" "$NEW"
