# SERP Ranking Checker

Personal tool to track Google Search Console rankings for my stores.

## Setup (One-time)

### 1. Install dependencies
```bash
cd serp-checker
go mod download
```

### 2. Set environment variable (already done in ~/.zshrc)
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/Users/matusstafura/.config/api.json"
```

### 3. Make scripts executable
```bash
chmod +x compare-rankings.sh
chmod +x check-changes.sh
```

## Configuration

Edit `config.yaml` to add/remove keywords:
```yaml
stores:
  - domain: "sc-domain:megamix.sk"
    country: "svk"
    keywords:
      - keyword: "akustická pena"
        volume: 100
      - keyword: "skumavky"
        volume: 50
```

## Daily Usage

### Run the checker (creates CSV file)
```bash
cd serp-checker
go run .
```

This creates a file like `rankings_2026-01-13.csv`

### Check what changed since last run
```bash
./check-changes.sh
```

### Compare specific dates
```bash
./compare-rankings.sh rankings_2026-01-12.csv rankings_2026-01-13.csv
```

### View latest CSV
```bash
# Quick view
cat rankings_$(date +%Y-%m-%d).csv

# View as table
column -t -s',' rankings_$(date +%Y-%m-%d).csv | less -S
```

## Files Generated

- `rankings_YYYY-MM-DD.csv` - Daily ranking snapshots
- Contains: domain, keyword, country, volume, position, clicks, impressions, CTR, dates

## Typical Workflow
```bash
# Monday morning - check rankings
cd serp-checker
go run .

# See what changed
./check-changes.sh

# Thursday evening - check again
go run .
./check-changes.sh
```

## Troubleshooting

### Program does nothing
```bash
# Check credentials are set
echo $GOOGLE_APPLICATION_CREDENTIALS

# Check if it compiles
go build

# Run with error output
go run . 2>&1
```

### No data for keyword
- Keyword might not have impressions in the date range (3-10 days ago)
- Check if keyword is ranking in Google Search Console manually
- GSC only shows data where your site appeared in results

### Permission denied error
- Make sure service account email is added to all stores in Google Search Console
- Go to: https://search.google.com/search-console → Settings → Users and permissions

## CSV Columns

1. `domain` - Store domain (sc-domain:megamix.sk)
2. `keyword` - Search term
3. `country` - Country code (svk)
4. `volume` - Monthly search volume (from config)
5. `position` - Average ranking position
6. `clicks` - Number of clicks
7. `impressions` - How many times appeared in search
8. `ctr` - Click-through rate (%)
9. `period_start` - Data period start date
10. `period_end` - Data period end date
11. `checked_at` - When this check was run

## Notes

- GSC data has 2-3 day lag, so we check 3-10 days ago
- Position is average over the period (not instant snapshot)
- Run twice per week is enough (Monday & Thursday)
- Focus on trends, not daily fluctuations
