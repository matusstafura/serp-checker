package main

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Keyword struct {
	Keyword string `yaml:"keyword"`
	Volume  int    `yaml:"volume"`
}

type Store struct {
	Domain   string    `yaml:"domain"`
	Country  string    `yaml:"country"`
	Keywords []Keyword `yaml:"keywords"`
}

type Config struct {
	Stores []Store `yaml:"stores"`
}

func LoadConfig(filename string) (*Config, error) {
	fmt.Printf("📂 Loading config from: %s\n", filename)

	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to read config: %w", err)
	}

	var config Config
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		return nil, fmt.Errorf("failed to parse config: %w", err)
	}

	fmt.Printf("✅ Loaded %d store(s)\n", len(config.Stores))

	// Count total keywords
	totalKeywords := 0
	for _, store := range config.Stores {
		totalKeywords += len(store.Keywords)
	}
	fmt.Printf("✅ Total keywords to track: %d\n", totalKeywords)

	return &config, nil
}
