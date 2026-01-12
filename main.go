package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"
)

func main() {
	fmt.Println("\n🚀 SERP Ranking Checker")
	fmt.Println("═══════════════════════════════════════════════════════════")

	// Check environment variable
	credsPath := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	if credsPath == "" {
		log.Fatal("❌ GOOGLE_APPLICATION_CREDENTIALS not set!")
	}
	fmt.Printf("🔐 Using credentials: %s\n", credsPath)

	// Load config
	config, err := LoadConfig("config.yaml")
	if err != nil {
		log.Fatalf("❌ Config error: %v", err)
	}

	// Initialize checker
	ctx := context.Background()
	checker, err := NewChecker(ctx)
	if err != nil {
		log.Fatalf("❌ Checker error: %v", err)
	}

	// Initialize CSV writer
	csvFile := fmt.Sprintf("rankings_%s.csv", time.Now().Format("2006-01-02"))
	writer, err := NewCSVWriter(csvFile)
	if err != nil {
		log.Fatalf("❌ Writer error: %v", err)
	}
	defer writer.Close()

	// Date range (3-10 days ago)
	endDate := time.Now().AddDate(0, 0, -3).Format("2006-01-02")
	startDate := time.Now().AddDate(0, 0, -10).Format("2006-01-02")

	fmt.Printf("📅 Period: %s to %s\n", startDate, endDate)
	fmt.Println("═══════════════════════════════════════════════════════════\n")

	// Stats
	totalKeywords := 0
	totalWithData := 0
	totalNoData := 0
	totalErrors := 0

	// Process each store
	for storeIdx, store := range config.Stores {
		fmt.Printf("\n[%d/%d] 🏪 Store: %s (Country: %s)\n",
			storeIdx+1, len(config.Stores), store.Domain, store.Country)
		fmt.Printf("     Keywords to check: %d\n", len(store.Keywords))

		for keywordIdx, kw := range store.Keywords { // Changed from 'keyword' to 'kw'
			totalKeywords++
			fmt.Printf("  [%d/%d] '%s' (vol: %d) ",
				keywordIdx+1, len(store.Keywords), kw.Keyword, kw.Volume) // Show volume

			// Check keyword - pass volume parameter
			result := checker.CheckKeyword(store.Domain, kw.Keyword, store.Country,
				startDate, endDate, kw.Volume)

			// Handle result
			if result.Error != nil {
				fmt.Printf("❌ Error: %v\n", result.Error)
				totalErrors++
				continue
			}

			if result.HasData {
				fmt.Printf("✅ Pos: %.1f | Impr: %d | Clicks: %d | CTR: %.1f%%\n",
					result.Position, result.Impressions, result.Clicks, result.CTR*100)

				// Write to CSV
				if err := writer.WriteResult(result); err != nil {
					fmt.Printf("     ⚠️  Failed to write: %v\n", err)
				} else {
					totalWithData++
				}
			} else {
				fmt.Printf("⚠️  No data (not ranking or no impressions)\n")
				totalNoData++
			}

			// Small delay to be nice to the API
			time.Sleep(100 * time.Millisecond)
		}
	}

	// Final summary
	fmt.Println("\n═══════════════════════════════════════════════════════════")
	fmt.Println("📊 SUMMARY")
	fmt.Println("═══════════════════════════════════════════════════════════")
	fmt.Printf("✅ Keywords with data: %d\n", totalWithData)
	fmt.Printf("⚠️  Keywords with no data: %d\n", totalNoData)
	fmt.Printf("❌ Errors: %d\n", totalErrors)
	fmt.Printf("📊 Total checked: %d\n", totalKeywords)
	fmt.Printf("💾 Results saved to: %s\n", csvFile)
	fmt.Println("═══════════════════════════════════════════════════════════\n")
}
