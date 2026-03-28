package handlers

import (
	"encoding/json"
	"net/http"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// isAdminOrSafetyManager returns true when the role is permitted to read/write
// admin settings. Both Admin and Safety Manager have this access.
func isAdminOrSafetyManager(role string) bool {
	return role == "admin" || role == "safety_manager"
}

// toJSON marshals v to a JSON string; returns "" on error.
func toJSON(v interface{}) string {
	b, _ := json.Marshal(v)
	return string(b)
}

// SeedDefaultSettings inserts the default settings rows when the settings
// table is empty. Safe to call on every startup — it is a no-op when rows
// already exist.
func SeedDefaultSettings(db *gorm.DB) {
	var count int64
	db.Model(&models.Setting{}).Count(&count)
	if count > 0 {
		return
	}

	defaults := []models.Setting{
		{
			Category:  "dashboard",
			Key:       "trir_benchmark",
			Value:     "3.0",
			UpdatedBy: "system",
		},
		{
			Category:  "investigation",
			Key:       "factor_types",
			Value:     `["People","Equipment","Environmental","Procedural","Management/Organizational"]`,
			UpdatedBy: "system",
		},
		{
			Category:  "notifications",
			Key:       "escalation_days",
			Value:     `[3,7,14]`,
			UpdatedBy: "system",
		},
	}

	db.Create(&defaults)
}

// SeedMissingSettings ensures any settings added after the initial seed are
// present on pre-existing databases. Safe to call on every startup — it is a
// no-op when all rows already exist.
func SeedMissingSettings(db *gorm.DB) {
	seedSettingIfMissing(db, models.Setting{
		Category:  "recurrence",
		Key:       "recurrence_lookback_months",
		Value:     "12",
		UpdatedBy: "system",
	})
}

// seedSettingIfMissing inserts a setting only when no row with the same key
// exists. Safe to call repeatedly.
func seedSettingIfMissing(db *gorm.DB, s models.Setting) {
	var count int64
	db.Model(&models.Setting{}).Where("key = ?", s.Key).Count(&count)
	if count == 0 {
		db.Create(&s)
	}
}

// ListSettings handles GET /api/settings.
// Restricted to Admin and Safety Manager.
// Optionally filter by ?category=<category>.
func ListSettings(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		role := middleware.GetUserRole(r)
		if !isAdminOrSafetyManager(role) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		query := db.Model(&models.Setting{})
		if cat := r.URL.Query().Get("category"); cat != "" {
			query = query.Where("category = ?", cat)
		}

		var settings []models.Setting
		if err := query.Find(&settings).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(settings)
	}
}

// GetSetting handles GET /api/settings/{key}.
// Accessible to all authenticated users — other features (e.g. investigations)
// need to read settings such as factor_types.
func GetSetting(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		key := r.PathValue("key")

		var setting models.Setting
		if err := db.Where("key = ?", key).First(&setting).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(setting)
	}
}

// UpdateSetting handles PUT /api/settings/{key}.
// Restricted to Admin and Safety Manager. Audit-logs the before/after value.
func UpdateSetting(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		role := middleware.GetUserRole(r)
		userID := middleware.GetUserID(r)

		if !isAdminOrSafetyManager(role) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		key := r.PathValue("key")

		var body struct {
			Value string `json:"value"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		var setting models.Setting
		if err := db.Where("key = ?", key).First(&setting).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		before := toJSON(setting)

		setting.Value = body.Value
		setting.UpdatedBy = userID

		if err := db.Save(&setting).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		after := toJSON(setting)
		LogAction(db, userID, role, "update", "setting", setting.ID, before, after, "")

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(setting)
	}
}

// RegisterSettingsRoutes wires up all settings endpoints on the given mux.
func RegisterSettingsRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("GET /api/settings", ListSettings(db))
	api.HandleFunc("GET /api/settings/{key}", GetSetting(db))
	api.HandleFunc("PUT /api/settings/{key}", UpdateSetting(db))
}
