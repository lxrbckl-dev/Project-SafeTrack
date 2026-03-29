package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/crypto"
	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// RegisterIncidentRoutes wires up all incident-related endpoints on the
// authenticated api mux.
func RegisterIncidentRoutes(api *http.ServeMux, db *gorm.DB) {
	// CRUD
	api.HandleFunc("POST /api/incidents", CreateIncident(db))
	api.HandleFunc("GET /api/incidents", ListIncidents(db))
	api.HandleFunc("GET /api/incidents/{id}", GetIncident(db))
	api.HandleFunc("PUT /api/incidents/{id}", UpdateIncident(db))

	// Photos
	api.HandleFunc("POST /api/incidents/{id}/photos", UploadIncidentPhoto(db))

	// OSHA
	api.HandleFunc("POST /api/incidents/{id}/osha-determination", OshaDetermination(db))
	api.HandleFunc("PUT /api/incidents/{id}/osha-override", OshaOverride(db))

	// Status management
	api.HandleFunc("POST /api/incidents/{id}/close", CloseIncident(db))
	api.HandleFunc("POST /api/incidents/{id}/reopen", ReopenIncident(db))
	api.HandleFunc("POST /api/incidents/{id}/status", TransitionIncidentStatus(db))
}

// ---------- helpers ----------

// canAccessMedical returns true if the user role is allowed to see
// decrypted medical data on injured persons.
// Edge case 11: agents are never allowed to view medical data, even if
// the underlying user role would otherwise permit it.
func canAccessMedical(role string, isAgent bool) bool {
	if isAgent {
		return false
	}
	switch role {
	case "safety_coordinator", "safety_manager", "admin":
		return true
	}
	return false
}

// CalculateCompletion returns the percentage of user-editable fields that
// have been filled in. Auto-generated fields (ID, Status, CreatedAt, etc.)
// are excluded.
func CalculateCompletion(inc *models.Incident) int {
	fields := []bool{
		inc.Type != "",
		!inc.Date.IsZero(),
		inc.Location != "",
		inc.Division != "",
		inc.ProjectJobSite != "",
		inc.Description != "",
		inc.ImmediateActions != "",
		inc.Severity != "",
		inc.PotentialSeverity != "",
		inc.Shift != "",
		inc.Weather != "",
	}
	filled := 0
	for _, f := range fields {
		if f {
			filled++
		}
	}
	return (filled * 100) / len(fields)
}

// encryptInjuredPersons encrypts medical fields on every InjuredPerson in
// the slice. Returns the first encryption error encountered, if any.
func encryptInjuredPersons(persons []models.InjuredPerson) error {
	for i := range persons {
		var err error
		if persons[i].InjuryType, err = crypto.Encrypt(persons[i].InjuryType); err != nil {
			return err
		}
		if persons[i].BodyPart, err = crypto.Encrypt(persons[i].BodyPart); err != nil {
			return err
		}
		if persons[i].TreatmentType, err = crypto.Encrypt(persons[i].TreatmentType); err != nil {
			return err
		}
		if persons[i].ReturnToWorkStatus, err = crypto.Encrypt(persons[i].ReturnToWorkStatus); err != nil {
			return err
		}
	}
	return nil
}

// decryptInjuredPersons decrypts medical fields in-place.
func decryptInjuredPersons(persons []models.InjuredPerson) {
	for i := range persons {
		persons[i].InjuryType, _ = crypto.Decrypt(persons[i].InjuryType)
		persons[i].BodyPart, _ = crypto.Decrypt(persons[i].BodyPart)
		persons[i].TreatmentType, _ = crypto.Decrypt(persons[i].TreatmentType)
		persons[i].ReturnToWorkStatus, _ = crypto.Decrypt(persons[i].ReturnToWorkStatus)
	}
}

// redactInjuredPersons replaces medical fields with "[RESTRICTED]".
func redactInjuredPersons(persons []models.InjuredPerson) {
	for i := range persons {
		persons[i].InjuryType = "[RESTRICTED]"
		persons[i].BodyPart = "[RESTRICTED]"
		persons[i].TreatmentType = "[RESTRICTED]"
		persons[i].ReturnToWorkStatus = "[RESTRICTED]"
	}
}

// ---------- CRUD ----------

// CreateIncident handles POST /api/incidents.
// Executive role is blocked (read-only).
func CreateIncident(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		// RBAC: Executive is read-only — cannot create.
		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		var incident models.Incident
		if err := json.NewDecoder(r.Body).Decode(&incident); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// Set reporter from auth context — never trust client-supplied values.
		incident.ReporterID = userID

		// Default status for new incidents.
		if incident.Status == "" {
			incident.Status = "Draft"
			incident.IsDraft = true
		}

		// Encrypt medical fields on injured persons before saving.
		if len(incident.InjuredPersons) > 0 {
			if err := encryptInjuredPersons(incident.InjuredPersons); err != nil {
				http.Error(w, "encryption error", http.StatusInternalServerError)
				return
			}
		}

		// Calculate completion percentage.
		incident.CompletionPercent = CalculateCompletion(&incident)

		// Check railroad notification overdue status.
		if incident.IsRailroadProperty && incident.RailroadClient != "" && !incident.RailroadNotified {
			incident.RailroadNotificationOverdue = CheckRailroadNotificationOverdue(&incident)
		}

		if err := db.Create(&incident).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "create", "incident", incident.ID, "", toJSON(incident), "", isAgent)

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(incident)
	}
}

// ListIncidents handles GET /api/incidents with query filters.
// Draft incidents are only visible to the reporter.
func ListIncidents(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		query := db.Model(&models.Incident{}).Preload("InjuredPersons")

		// CRITICAL: Draft incidents visible only to the reporter.
		query = query.Where("(is_draft = false OR reporter_id = ?)", userID)

		// RBAC: PM scoped data — filter by matching project from JWT claim.
		if userRole == "pm" {
			if project := middleware.GetUserProject(r); project != "" {
				query = query.Where("project_job_site = ?", project)
			}
		}

		// RBAC: Division Manager scoped data — filter by matching division from JWT claim.
		if userRole == "division_manager" {
			if division := middleware.GetUserDivision(r); division != "" {
				query = query.Where("division = ?", division)
			}
		}

		// Optional filters.
		if status := r.URL.Query().Get("status"); status != "" {
			query = query.Where("status = ?", status)
		}
		if typ := r.URL.Query().Get("type"); typ != "" {
			query = query.Where("type = ?", typ)
		}
		if div := r.URL.Query().Get("division"); div != "" {
			query = query.Where("division = ?", div)
		}
		if rid := r.URL.Query().Get("reporter_id"); rid != "" {
			query = query.Where("reporter_id = ?", rid)
		}

		// Pagination.
		page := 1
		perPage := 25
		if p := r.URL.Query().Get("page"); p != "" {
			if v, err := strconv.Atoi(p); err == nil && v > 0 {
				page = v
			}
		}
		if pp := r.URL.Query().Get("per_page"); pp != "" {
			if v, err := strconv.Atoi(pp); err == nil && v > 0 && v <= 500 {
				perPage = v
			}
		}

		var total int64
		query.Count(&total)

		var incidents []models.Incident
		query.Order("created_at desc").
			Offset((page - 1) * perPage).
			Limit(perPage).
			Find(&incidents)

		// Handle medical data visibility.
		medicalAccess := canAccessMedical(userRole, isAgent)
		for i := range incidents {
			if len(incidents[i].InjuredPersons) > 0 {
				if medicalAccess {
					decryptInjuredPersons(incidents[i].InjuredPersons)
				} else {
					redactInjuredPersons(incidents[i].InjuredPersons)
				}
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"data":     incidents,
			"total":    total,
			"page":     page,
			"per_page": perPage,
		})
	}
}

// GetIncident handles GET /api/incidents/{id}.
func GetIncident(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		id := r.PathValue("id")
		var incident models.Incident
		if err := db.Preload("InjuredPersons").Preload("Photos").First(&incident, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// Draft visibility: only reporter can see their own drafts.
		if incident.IsDraft && incident.ReporterID != userID {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// RBAC: PM scoped — can only view incidents matching their project.
		if userRole == "pm" {
			if project := middleware.GetUserProject(r); project != "" && incident.ProjectJobSite != project {
				http.Error(w, "not found", http.StatusNotFound)
				return
			}
		}

		// RBAC: Division Manager scoped — can only view incidents in their division.
		if userRole == "division_manager" {
			if division := middleware.GetUserDivision(r); division != "" && incident.Division != division {
				http.Error(w, "not found", http.StatusNotFound)
				return
			}
		}

		// Medical field access control.
		if len(incident.InjuredPersons) > 0 {
			if canAccessMedical(userRole, isAgent) {
				decryptInjuredPersons(incident.InjuredPersons)
			} else {
				redactInjuredPersons(incident.InjuredPersons)
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(incident)
	}
}

// UpdateIncident handles PUT /api/incidents/{id}.
// Executive role is blocked (read-only).
func UpdateIncident(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		// RBAC: Executive is read-only — cannot update.
		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		id := r.PathValue("id")
		var existing models.Incident
		if err := db.Preload("InjuredPersons").First(&existing, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		beforeJSON := toJSON(existing)

		var updates models.Incident
		if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// Apply scalar field updates.
		existing.Type = updates.Type
		existing.Date = updates.Date
		existing.Location = updates.Location
		existing.Latitude = updates.Latitude
		existing.Longitude = updates.Longitude
		existing.Division = updates.Division
		existing.ProjectJobSite = updates.ProjectJobSite
		existing.Description = updates.Description
		existing.ImmediateActions = updates.ImmediateActions
		existing.Severity = updates.Severity
		existing.PotentialSeverity = updates.PotentialSeverity
		existing.Shift = updates.Shift
		existing.Weather = updates.Weather
		existing.IsRailroadProperty = updates.IsRailroadProperty
		existing.RailroadClient = updates.RailroadClient
		existing.RailroadNotified = updates.RailroadNotified
		existing.RailroadNotificationDate = updates.RailroadNotificationDate
		existing.RailroadNotificationMethod = updates.RailroadNotificationMethod

		// If the client is submitting the draft (transitioning from Draft to Reported):
		if updates.IsDraft != existing.IsDraft {
			existing.IsDraft = updates.IsDraft
			if !updates.IsDraft {
				existing.Status = "Reported"
			}
		}

		// Re-encrypt injured persons if provided.
		if len(updates.InjuredPersons) > 0 {
			if err := encryptInjuredPersons(updates.InjuredPersons); err != nil {
				http.Error(w, "encryption error", http.StatusInternalServerError)
				return
			}
			// Delete old injured persons, replace with new set.
			db.Where("incident_id = ?", existing.ID).Delete(&models.InjuredPerson{})
			for i := range updates.InjuredPersons {
				updates.InjuredPersons[i].IncidentID = existing.ID
				updates.InjuredPersons[i].ID = 0 // let GORM assign new IDs
			}
			existing.InjuredPersons = updates.InjuredPersons
		}

		// Recalculate completion.
		existing.CompletionPercent = CalculateCompletion(&existing)

		// Check railroad notification overdue.
		if existing.IsRailroadProperty && existing.RailroadClient != "" && !existing.RailroadNotified {
			existing.RailroadNotificationOverdue = CheckRailroadNotificationOverdue(&existing)
		} else {
			existing.RailroadNotificationOverdue = false
		}

		if err := db.Save(&existing).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Save new injured persons if they were replaced.
		if len(updates.InjuredPersons) > 0 {
			for i := range existing.InjuredPersons {
				db.Create(&existing.InjuredPersons[i])
			}
		}

		LogAction(db, userID, userRole, "update", "incident", existing.ID, beforeJSON, toJSON(existing), "", isAgent)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(existing)
	}
}
