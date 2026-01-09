package main

import (
    "context"
    "fmt"
    "time"

    "google.golang.org/api/option"
    "google.golang.org/api/searchconsole/v1"
)

type RankingResult struct {
    Domain      string
    Keyword     string
    Country     string
    Position    float64
    Clicks      int64
    Impressions int64
    CTR         float64
    PeriodStart string
    PeriodEnd   string
    CheckedAt   string
    HasData     bool
    Error       error
}

type Checker struct {
    service *searchconsole.Service
}

func NewChecker(ctx context.Context) (*Checker, error) {
    fmt.Println("🔑 Connecting to Google Search Console API...")
    
    service, err := searchconsole.NewService(ctx, 
        option.WithScopes(searchconsole.WebmastersReadonlyScope))
    if err != nil {
        return nil, fmt.Errorf("failed to create service: %w", err)
    }
    
    fmt.Println("✅ Connected to API")
    return &Checker{service: service}, nil
}

func (c *Checker) CheckKeyword(domain, keyword, country, startDate, endDate string) RankingResult {
    result := RankingResult{
        Domain:      domain,
        Keyword:     keyword,
        Country:     country,
        PeriodStart: startDate,
        PeriodEnd:   endDate,
        CheckedAt:   time.Now().Format("2006-01-02 15:04:05"),
        HasData:     false,
    }

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
                        Expression: country,
                    },
                },
            },
        },
        RowLimit: 1,
    }

    resp, err := c.service.Searchanalytics.Query(domain, request).Do()
    if err != nil {
        result.Error = err
        return result
    }

    if len(resp.Rows) > 0 {
        row := resp.Rows[0]
        result.HasData = true
        result.Position = row.Position
        result.Clicks = int64(row.Clicks)
        result.Impressions = int64(row.Impressions)
        result.CTR = row.Ctr
    }

    return result
}
