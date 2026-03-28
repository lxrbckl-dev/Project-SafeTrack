package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// RegisterInvestigationRoutes wires up all investigation-related endpoints on
// the authenticated api mux.
func RegisterInvestigationRoutes(api *http.ServeMux, db *gorm.DB) {
	// CRUD
	api.HandleFunc("POST /api/investigations", CreateInvestigation(db))
	api.HandleFunc("GET /api/investigations", ListInvestigations(db))
	api.HandleFunc("GET /api/investigations/{id}", GetInvestigation(db))
	api.HandleFunc("PUT /api/investigations/{id}", UpdateInvestigation(db))

	// Five-Why CRUD
	api.HandleFunc("POST /api/investigations/{id}/five-whys", CreateOrUpdateFiveWhy(db))
	api.HandleFunc("DELETE /api/investigations/{id}/five-whys/{whyId}", DeleteFiveWhy(db))

	// Contributing Factors
	api.HandleFunc("POST /api/investigations/{id}/factors", CreateContributingFactor(db))
	api.HandleFunc("DELETE /api/investigations/{id}/factors/{factorId}", DeleteContributingFactor(db))

	// Witness Statements
	api.HandleFunc("POST /api/investigations/{id}/witnesses", CreateWitnessStatement(db))
	api.HandleFunc("PUT /api/investigations/{id}/witnesses/{witnessId}", UpdateWitnessStatement(db))

	// Workflow
	api.HandleFunc("POST /api/investigations/{id}/submit-for-review", SubmitForReview(db))
	api.HandleFunc("POST /api/investigations/{id}/review", ReviewInvestigation(db))
}

// ---------- helpers ----------

// targetCompletionDate calculates the deadline based on incident severity.
// Fatality = 48 hours (2 calendar days), Lost Time = 5 business days,
// Medical Treatment = 10 calendar days, First Aid/Near Miss = 14 calendar days.
func targetCompletionDate(severity string, from time.Time) time.Time {
	switch severity {
	case "Fatality":
		return from.Add(48 * time.Hour) // 2 calendar days
	case "Lost Time":
		return AddBusinessDays(from, 5) // 5 business days
	case "Medical Treatment":
		return from.AddDate(0, 0, 10) // 10 calendar days
	case "First Aid", "Near Miss":
		return from.AddDate(0, 0, 14) // 14 calendar days
	default:
		return from.AddDate(0, 0, 14) // default: 14 calendar days
	}
}

// updateOverdueStatus recalculates the IsOverdue flag and OverdueEscalationLevel
// for an investigation. Call on GET requests for real-time accuracy.
func updateOverdueStatus(inv *models.Investigation) {
	if inv.Status == "Approved" {
		inv.IsOverdue = false
		inv.OverdueEscalationLevel = 0
		return
	}

	now := time.Now()
	if now.Before(inv.TargetCompletionDate) {
		inv.IsOverdue = false
		inv.OverdueEscalationLevel = 0
		return
	}

	inv.IsOverdue = true
	overdueDays := int(now.Sub(inv.TargetCompletionDate).Hours() / 24)

	switch {
	case overdueDays >= 8:
		inv.OverdueEscalationLevel = 3
	case overdueDays >= 4:
		inv.OverdueEscalationLevel = 2
	default:
		inv.OverdueEscalationLevel = 1 // 1-3 days overdue
	}
}

// ---------- CRUD ----------

// createInvestigationRequest is the JSON body for POST /api/investigations.
type createInvestigationRequest struct {
	IncidentID         uint   `json:"incidentId"`
	LeadInvestigatorID string `json:"leadInvestigatorId"`
	TeamMembers        string `json:"teamMembers"`
}

// CreateInvestigation handles POST /api/investigations.
// Safety Manager only. Auto-sets TargetCompletionDate based on incident severity.
// Updates the incident status to "Under Investigation".
func CreateInvestigation(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		// RBAC: Safety Manager only.
		if userRole != "safety_manager" && userRole != "admin" {
			http.Error(w, "forbidden: only Safety Manager can assign investigations", http.StatusForbidden)
			return
		}

		var req createInvestigationRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if req.IncidentID == 0 || req.LeadInvestigatorID == "" {
			http.Error(w, "incidentId and leadInvestigatorId are required", http.StatusBadRequest)
			return
		}

		// Look up the incident to get severity for deadline calculation.
		var incident models.Incident
		if err := db.First(&incident, req.IncidentID).Error; err != nil {
			http.Error(w, "incident not found", http.StatusNotFound)
			return
		}

		// Check that an investigation doesn't already exist for this incident.
		var existingCount int64
		db.Model(&models.Investigation{}).Where("incident_id = ?", req.IncidentID).Count(&existingCount)
		if existingCount > 0 {
			http.Error(w, "investigation already exists for this incident", http.StatusConflict)
			return
		}

		now := time.Now()
		investigation := models.Investigation{
			IncidentID:           req.IncidentID,
			LeadInvestigatorID:   req.LeadInvestigatorID,
			TeamMembers:          req.TeamMembers,
			TargetCompletionDate: targetCompletionDate(incident.Severity, now),
			Status:               "Assigned",
			AssignedBy:           userID,
		}

		if err := db.Create(&investigation).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Update incident status to "Under Investigation".
		incidentBefore := toJSON(incident)
		incident.Status = "Under Investigation"
		if err := db.Save(&incident).Error; err != nil {
			http.Error(w, "database error updating incident status", http.StatusInternalServerError)
			return
		}
		LogAction(db, userID, userRole, "status_change", "incident", incident.ID, incidentBefore, toJSON(incident), "Investigation assigned")

		LogAction(db, userID, userRole, "create", "investigation", investigation.ID, "", toJSON(investigation), fmt.Sprintf("Investigation assigned to %s for incident %d", req.LeadInvestigatorID, req.IncidentID))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(investigation)
	}
}

// ListInvestigations handles GET /api/investigations with query filters.
// Supports: ?status=, ?investigator_id=, ?incident_id=, ?overdue=true
func ListInvestigations(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		query := db.Model(&models.Investigation{})

		// Optional filters.
		if status := r.URL.Query().Get("status"); status != "" {
			query = query.Where("status = ?", status)
		}
		if investigatorID := r.URL.Query().Get("investigator_id"); investigatorID != "" {
			query = query.Where("lead_investigator_id = ?", investigatorID)
		}
		if incidentID := r.URL.Query().Get("incident_id"); incidentID != "" {
			query = query.Where("incident_id = ?", incidentID)
		}
		if overdue := r.URL.Query().Get("overdue"); overdue == "true" {
			query = query.Where("is_overdue = ?", true)
		}

		// Pagination.
		page := 1
		perPage := 50
		if p := r.URL.Query().Get("page"); p != "" {
			if v, err := strconv.Atoi(p); err == nil && v > 0 {
				page = v
			}
		}
		if pp := r.URL.Query().Get("per_page"); pp != "" {
			if v, err := strconv.Atoi(pp); err == nil && v > 0 && v <= 100 {
				perPage = v
			}
		}

		var total int64
		query.Count(&total)

		var investigations []models.Investigation
		query.Order("created_at desc").
			Offset((page - 1) * perPage).
			Limit(perPage).
			Find(&investigations)

		// Update overdue status in real-time for each result.
		for i := range investigations {
			updateOverdueStatus(&investigations[i])
			// Persist the updated overdue flags.
			db.Model(&investigations[i]).Updates(map[string]interface{}{
				"is_overdue":               investigations[i].IsOverdue,
				"overdue_escalation_level": investigations[i].OverdueEscalationLevel,
			})
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"data":     investigations,
			"total":    total,
			"page":     page,
			"per_page": perPage,
		})
	}
}

// GetInvestigation handles GET /api/investigations/{id}.
// Returns the investigation with preloaded FiveWhys, ContributingFactors,
// and WitnessStatements. FiveWhys are ordered by SortOrder.
func GetInvestigation(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := r.PathValue("id")
		var investigation models.Investigation
		if err := db.
			Preload("FiveWhys", func(db *gorm.DB) *gorm.DB {
				return db.Order("sort_order ASC")
			}).
			Preload("ContributingFactors").
			Preload("WitnessStatements").
			First(&investigation, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// Update overdue status in real-time.
		updateOverdueStatus(&investigation)
		db.Model(&investigation).Updates(map[string]interface{}{
			"is_overdue":               investigation.IsOverdue,
			"overdue_escalation_level": investigation.OverdueEscalationLevel,
		})

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(investigation)
	}
}

// UpdateInvestigation handles PUT /api/investigations/{id}.
func UpdateInvestigation(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		id := r.PathValue("id")
		var existing models.Investigation
		if err := db.First(&existing, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		beforeJSON := toJSON(existing)

		var updates struct {
			LeadInvestigatorID string `json:"leadInvestigatorId"`
			TeamMembers        string `json:"teamMembers"`
			Status             string `json:"status"`
		}
		if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if updates.LeadInvestigatorID != "" {
			existing.LeadInvestigatorID = updates.LeadInvestigatorID
		}
		if updates.TeamMembers != "" {
			existing.TeamMembers = updates.TeamMembers
		}
		if updates.Status != "" {
			existing.Status = updates.Status
		}

		if err := db.Save(&existing).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "update", "investigation", existing.ID, beforeJSON, toJSON(existing), "")

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(existing)
	}
}
