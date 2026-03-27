package handlers

import (
	"encoding/json"
	"net/http"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/lxRbckl/highlander/backend/internal/models"
)

type SyncRequest struct {
	Records []models.Note `json:"records"`
}

type SyncResponse struct {
	Synced int `json:"synced"`
	Failed int `json:"failed"`
}

func Sync(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req SyncRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		synced := 0
		failed := 0

		for _, record := range req.Records {
			result := db.Clauses(clause.OnConflict{
				Columns:   []clause.Column{{Name: "id"}},
				DoUpdates: clause.AssignmentColumns([]string{"content"}),
			}).Create(&record)

			if result.Error != nil {
				failed++
				continue
			}
			synced++
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(SyncResponse{Synced: synced, Failed: failed})
	}
}

func GetData(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var records []models.Note
		if err := db.Order("created_at desc").Find(&records).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(records)
	}
}
