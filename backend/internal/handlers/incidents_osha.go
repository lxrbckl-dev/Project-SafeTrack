package handlers

import (
	"encoding/json"
	"net/http"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// oshaRequest carries the answers from the OSHA 29 CFR 1904 decision tree.
type oshaRequest struct {
	WorkRelated          bool `json:"workRelated"`
	Death                bool `json:"death"`
	DaysAway             bool `json:"daysAway"`
	RestrictedTransfer   bool `json:"restrictedTransfer"`
	MedicalTreatment     bool `json:"medicalTreatment"`
	LossOfConsciousness  bool `json:"lossOfConsciousness"`
	SignificantDiagnosis bool `json:"significantDiagnosis"`
}

// OshaDetermination handles POST /api/incidents/{id}/osha-determination.
// It applies the 29 CFR 1904 decision tree to determine OSHA recordability
// and DART status, then persists the result on the incident.
// Executive role is blocked (read-only).
func OshaDetermination(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		// RBAC: Executive is read-only.
		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		id := r.PathValue("id")
		var incident models.Incident
		if err := db.First(&incident, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		var req oshaRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		beforeJSON := toJSON(incident)

		recordable := false
		dart := false

		if req.WorkRelated {
			if req.Death || req.DaysAway || req.RestrictedTransfer ||
				req.MedicalTreatment || req.LossOfConsciousness || req.SignificantDiagnosis {
				recordable = true
			}
			// DART flag set if days away OR restricted duty/transfer.
			if req.DaysAway || req.RestrictedTransfer {
				dart = true
			}
		}

		incident.IsOshaRecordable = &recordable
		incident.IsDart = &dart

		if err := db.Save(&incident).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "osha_determination", "incident", incident.ID, beforeJSON, toJSON(incident),
			"OSHA determination applied — recordable="+boolStr(recordable)+", DART="+boolStr(dart), isAgent)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(incident)
	}
}

// oshaOverrideRequest carries the override fields.
type oshaOverrideRequest struct {
	IsOshaRecordable bool   `json:"isOshaRecordable"`
	Justification    string `json:"justification"`
}

// OshaOverride handles PUT /api/incidents/{id}/osha-override.
// A justification is required. The override and justification are audit-logged.
// Executive role is blocked (read-only).
func OshaOverride(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		// RBAC: Executive is read-only.
		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		id := r.PathValue("id")
		var incident models.Incident
		if err := db.First(&incident, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		var req oshaOverrideRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if req.Justification == "" {
			http.Error(w, "justification is required for OSHA override", http.StatusBadRequest)
			return
		}

		beforeJSON := toJSON(incident)

		incident.IsOshaRecordable = &req.IsOshaRecordable
		incident.OshaOverrideJustification = req.Justification

		if err := db.Save(&incident).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "osha_override", "incident", incident.ID, beforeJSON, toJSON(incident), req.Justification, isAgent)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(incident)
	}
}

// boolStr converts a bool to "true"/"false" for audit log notes.
func boolStr(b bool) string {
	if b {
		return "true"
	}
	return "false"
}
