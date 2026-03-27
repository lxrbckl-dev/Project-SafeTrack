package database

import (
	"fmt"
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/models"
)

func Connect(databaseURL string) (*gorm.DB, error) {
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("opening database: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("getting underlying db: %w", err)
	}

	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(5)

	// Auto-migrate all models — tables are created/updated automatically
	if err := db.AutoMigrate(models.AllModels()...); err != nil {
		return nil, fmt.Errorf("auto-migrate: %w", err)
	}

	log.Println("Database connected and migrated")
	return db, nil
}
