package utils

import (
	"os"
	"strconv"

	log "github.com/sirupsen/logrus"
)

func GetEnvAsString(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func GetEnvAsInt(key string, fallback int) int {
	if value, ok := os.LookupEnv(key); ok {
		v, err := strconv.Atoi(value)
		if err != nil {
			log.Errorf("Failed to open local db with error: %v", err)
		}
		return v
	}
	return fallback
}
