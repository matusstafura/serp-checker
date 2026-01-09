package main

import (
    "fmt"
    "os"

    "gopkg.in/yaml.v3"
)

type Store struct {
    Domain   string   `yaml:"domain"`
    Country  string   `yaml:"country"`
    Keywords []string `yaml:"keywords"`
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
    return &config, nil
}
