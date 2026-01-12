package main

import (
	"encoding/csv"
	"fmt"
	"os"
	"strconv"
)

type CSVWriter struct {
	filename string
	file     *os.File
	writer   *csv.Writer
}

func NewCSVWriter(filename string) (*CSVWriter, error) {
	fmt.Printf("📝 Opening CSV file: %s\n", filename)

	// Check if file exists to determine if we need headers
	fileExists := false
	if _, err := os.Stat(filename); err == nil {
		fileExists = true
	}

	file, err := os.OpenFile(filename, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}

	writer := csv.NewWriter(file)

	// Write header if new file
	if !fileExists {
		header := []string{
			"domain", "keyword", "country", "volume", "position", // Added volume here
			"clicks", "impressions", "ctr",
			"period_start", "period_end", "checked_at",
		}
		if err := writer.Write(header); err != nil {
			file.Close()
			return nil, fmt.Errorf("failed to write header: %w", err)
		}
		writer.Flush()
	}

	return &CSVWriter{
		filename: filename,
		file:     file,
		writer:   writer,
	}, nil
}

func (w *CSVWriter) WriteResult(result RankingResult) error {
	if !result.HasData {
		return nil // Skip results with no data
	}

	record := []string{
		result.Domain,
		result.Keyword,
		result.Country,
		strconv.Itoa(result.Volume), // Added volume here
		strconv.FormatFloat(result.Position, 'f', 2, 64),
		strconv.FormatInt(result.Clicks, 10),
		strconv.FormatInt(result.Impressions, 10),
		strconv.FormatFloat(result.CTR*100, 'f', 2, 64),
		result.PeriodStart,
		result.PeriodEnd,
		result.CheckedAt,
	}

	return w.writer.Write(record)
}

func (w *CSVWriter) Close() error {
	w.writer.Flush()
	return w.file.Close()
}
