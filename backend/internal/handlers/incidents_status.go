package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// validTransitions maps current status to the set of allowed next statuses.
var validTransitions = map[string][]string{
	"Draft":                  {"Reported"},
	"Reported":               {"Under Investigation"},
	"Under Investigation":    {"Investigation Complete"},
	"Investigation Complete": {"CAPA Assigned"},
	"CAPA Assigned":          {"CAPA In Progress"},
	"CAPA In Progress":       {"Closed"},
	"Closed":                 {"Reopened"},
	"Reopened":               {"Under Investigation"},
}

// isValidTransition checks whether moving from current to next status is allowed.
func isValidTransition(current, next string) bool {
	allowed, ok := validTransitions[current]
	if !ok {
		return false
	}
	for _, s := range allowed {
		if s == next {
			return true
		}
	}
	return false
}

// statusTransitionRequest is the JSON body for POST /api/incidents/{id}/status.
type statusTransitionRequest struct {
	Status string `json:"status"`
}

// TransitionIncidentStatus handles POST /api/incidents/{id}/status.
// Validates that the requested status transition is allowed.
func TransitionIncidentStatus(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		id := r.PathValue("id")
		var incident models.Incident
		if err := db.First(&incident, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		var req statusTransitionRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Status == "" {
			http.Error(w, "invalid request body — status required", http.StatusBadRequest)
			return
		}

		if !isValidTransition(incident.Status, req.Status) {
			http.Error(w, "invalid status transition from "+incident.Status+" to "+req.Status, http.StatusBadRequest)
			return
		}

		beforeJSON := toJSON(incident)
		incident.Status = req.Status

		// If transitioning out of Draft, clear IsDraft.
		if req.Status == "Reported" {
			incident.IsDraft = false
		}

		if err := db.Save(&incident).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "status_change", "incident", incident.ID, beforeJSON, toJSON(incident), "Status changed to "+req.Status)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(incident)
	}
}

// CloseIncident handles POST /api/incidents/{id}/close.
// Validates all CAPAs for this incident are Verified Effective before closing.
func CloseIncident(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		id := r.PathValue("id")
		var incident models.Incident
		if err := db.First(&incident, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// TODO: When the CAPA model exists, validate that all CAPAs for this
		// incident have status "Verified Effective" before allowing close.
		// For now, allow close without CAPA validation.
		//
		// Example future code:
		//   var unverifiedCount int64
		//   db.Model(&models.CAPA{}).
		//     Where("incident_id = ? AND status != ?", incident.ID, "Verified Effective").
		//     Count(&unverifiedCount)
		//   if unverifiedCount > 0 {
		//     http.Error(w, "all CAPAs must be Verified Effective before closing", http.StatusBadRequest)
		//     return
		//   }

		beforeJSON := toJSON(incident)
		incident.Status = "Closed"

		if err := db.Save(&incident).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "status_change", "incident", incident.ID, beforeJSON, toJSON(incident), "Incident closed")

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(incident)
	}
}

// ReopenIncident handles POST /api/incidents/{id}/reopen.
func ReopenIncident(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		id := r.PathValue("id")
		var incident models.Incident
		if err := db.First(&incident, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		if incident.Status != "Closed" {
			http.Error(w, "only closed incidents can be reopened", http.StatusBadRequest)
			return
		}

		beforeJSON := toJSON(incident)
		incident.Status = "Reopened"

		if err := db.Save(&incident).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "status_change", "incident", incident.ID, beforeJSON, toJSON(incident), "Incident reopened")

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(incident)
	}
}

// AddBusinessDays adds the given number of business days (skipping weekends)
// to start and returns the resulting time.
func AddBusinessDays(start time.Time, days int) time.Time {
	current := start
	added := 0
	for added < days {
		current = current.AddDate(0, 0, 1)
		if current.Weekday() != time.Saturday && current.Weekday() != time.Sunday {
			added++
		}
	}
	return current
}
