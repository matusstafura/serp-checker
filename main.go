package main

import (
    "context"
    "database/sql"
    "fmt"
    "log"
    "time"

    _ "github.com/mattn/go-sqlite3"
    "google.golang.org/api/option"
    "google.golang.org/api/searchconsole/v1"
)

type Store struct {
    Domain   string
    Country  string
    Keywords []string
}

func initDB() *sql.DB {
    db, err := sql.Open("sqlite3", "./serp_rankings.db")
    if err != nil {
        log.Fatal(err)
    }

    schema := `
    CREATE TABLE IF NOT EXISTS rankings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT NOT NULL,
        keyword TEXT NOT NULL,
        country TEXT NOT NULL,
        position REAL NOT NULL,
        clicks INTEGER NOT NULL,
        impressions INTEGER NOT NULL,
        ctr REAL NOT NULL,
        period_start DATE NOT NULL,
        period_end DATE NOT NULL,
        checked_at DATETIME NOT NULL,
        UNIQUE(domain, keyword, country, checked_at)
    );
    
    CREATE TABLE IF NOT EXISTS api_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date DATE NOT NULL UNIQUE,
        api_calls INTEGER NOT NULL DEFAULT 0,
        successful_calls INTEGER NOT NULL DEFAULT 0,
        failed_calls INTEGER NOT NULL DEFAULT 0
    );
    
    CREATE INDEX IF NOT EXISTS idx_domain_keyword ON rankings(domain, keyword);
    CREATE INDEX IF NOT EXISTS idx_checked_at ON rankings(checked_at);
    `

    _, err = db.Exec(schema)
    if err != nil {
        log.Fatal(err)
    }

    return db
}

func saveRanking(db *sql.DB, domain, keyword, country string, 
                 position float64, clicks, impressions int64, ctr float64,
                 periodStart, periodEnd, checkedAt string) error {
    
    query := `
    INSERT OR REPLACE INTO rankings 
    (domain, keyword, country, position, clicks, impressions, ctr, 
     period_start, period_end, checked_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `
    
    _, err := db.Exec(query, domain, keyword, country, position, 
                      clicks, impressions, ctr, periodStart, periodEnd, checkedAt)
    return err
}

func trackAPICall(db *sql.DB, success bool) {
    today := time.Now().Format("2006-01-02")
    
    query := `
    INSERT INTO api_usage (date, api_calls, successful_calls, failed_calls)
    VALUES (?, 1, ?, ?)
    ON CONFLICT(date) DO UPDATE SET
        api_calls = api_calls + 1,
        successful_calls = successful_calls + ?,
        failed_calls = failed_calls + ?
    `
    
    successInt := 0
    failInt := 0
    if success {
        successInt = 1
    } else {
        failInt = 1
    }
    
    _, err := db.Exec(query, today, successInt, failInt, successInt, failInt)
    if err != nil {
        log.Printf("Warning: Failed to track API call: %v", err)
    }
}

func getTodayUsage(db *sql.DB) (total, successful, failed int) {
    today := time.Now().Format("2006-01-02")
    
    query := `SELECT api_calls, successful_calls, failed_calls 
              FROM api_usage WHERE date = ?`
    
    err := db.QueryRow(query, today).Scan(&total, &successful, &failed)
    if err != nil && err != sql.ErrNoRows {
        log.Printf("Warning: Failed to get today's usage: %v", err)
    }
    
    return
}

func main() {
    ctx := context.Background()
    
    // Initialize database
    db := initDB()
    defer db.Close()
    
    // Initialize Search Console API
    service, err := searchconsole.NewService(ctx, 
        option.WithScopes(searchconsole.WebmastersReadonlyScope))
    if err != nil {
        log.Fatal(err)
    }

    // Config
    stores := []Store{
        {
            Domain:   "sc-domain:megamix.sk",
            Country:  "svk",
            Keywords: []string{"akustická pena", "skumavky"},
        },
        // Add your other 5 stores here
    }

    // Date range
    endDate := time.Now().AddDate(0, 0, -3).Format("2006-01-02")
    startDate := time.Now().AddDate(0, 0, -10).Format("2006-01-02")
    checkedAt := time.Now().Format("2006-01-02 15:04:05")

    // Get today's usage before starting
    beforeTotal, beforeSuccess, beforeFailed := getTodayUsage(db)
    
    fmt.Printf("╔════════════════════════════════════════════════════════════╗\n")
    fmt.Printf("║ SERP Ranking Check - %s ║\n", time.Now().Format("2006-01-02 15:04"))
    fmt.Printf("╠════════════════════════════════════════════════════════════╣\n")
    fmt.Printf("║ Period: %s to %s                        ║\n", startDate, endDate)
    fmt.Printf("║ API calls today (before): %d / 1200                     ║\n", beforeTotal)
    fmt.Printf("╚════════════════════════════════════════════════════════════╝\n\n")

    totalSaved := 0
    apiCallsThisRun := 0

    for _, store := range stores {
        fmt.Printf("\n%s\n", "============================================================")
        fmt.Printf("Store: %s | Country: %s\n", store.Domain, store.Country)
        fmt.Printf("%s\n", "============================================================")

        for _, keyword := range store.Keywords {
            request := &searchconsole.SearchAnalyticsQueryRequest{
                StartDate:  startDate,
                EndDate:    endDate,
                Dimensions: []string{"query"},
                DimensionFilterGroups: []*searchconsole.ApiDimensionFilterGroup{
                    {
                        Filters: []*searchconsole.ApiDimensionFilter{
                            {
                                Dimension:  "query",
                                Operator:   "equals",
                                Expression: keyword,
                            },
                            {
                                Dimension:  "country",
                                Operator:   "equals",
                                Expression: store.Country,
                            },
                        },
                    },
                },
                RowLimit: 1,
            }

            // Make API call
            apiCallsThisRun++
            resp, err := service.Searchanalytics.Query(store.Domain, request).Do()
            
            if err != nil {
                fmt.Printf("\n⚠️  %s - Error: %v\n", keyword, err)
                trackAPICall(db, false)
                continue
            }
            
            trackAPICall(db, true)

            if len(resp.Rows) > 0 {
                row := resp.Rows[0]
                fmt.Printf("\n✅ %s\n", keyword)
                fmt.Printf("   Position: %.1f\n", row.Position)
                fmt.Printf("   Clicks: %d\n", int64(row.Clicks))
                fmt.Printf("   Impressions: %d\n", int64(row.Impressions))
                fmt.Printf("   CTR: %.2f%%\n", row.Ctr*100)

                // Save to database
                err = saveRanking(db, store.Domain, keyword, store.Country,
                    row.Position, int64(row.Clicks), int64(row.Impressions), 
                    row.Ctr, startDate, endDate, checkedAt)
                
                if err != nil {
                    fmt.Printf("   ⚠️  Failed to save: %v\n", err)
                } else {
                    fmt.Printf("   💾 Saved (checked at: %s)\n", checkedAt)
                    totalSaved++
                }
            } else {
                fmt.Printf("\n❌ %s - No data\n", keyword)
            }
        }
    }
    
    // Get final usage
    afterTotal, afterSuccess, afterFailed := getTodayUsage(db)
    
    fmt.Printf("\n╔════════════════════════════════════════════════════════════╗\n")
    fmt.Printf("║ Summary                                                    ║\n")
    fmt.Printf("╠════════════════════════════════════════════════════════════╣\n")
    fmt.Printf("║ Rankings saved: %-3d                                       ║\n", totalSaved)
    fmt.Printf("║ API calls this run: %-3d                                   ║\n", apiCallsThisRun)
    fmt.Printf("║ API calls today: %d / 1200 (%.1f%% used)               ║\n", 
               afterTotal, float64(afterTotal)/1200*100)
    fmt.Printf("║ Remaining today: %-4d                                     ║\n", 1200-afterTotal)
    fmt.Printf("║ Success rate: %d/%d (%.1f%%)                            ║\n", 
               afterSuccess, afterTotal, float64(afterSuccess)/float64(afterTotal)*100)
    fmt.Printf("╚════════════════════════════════════════════════════════════╝\n")
}
