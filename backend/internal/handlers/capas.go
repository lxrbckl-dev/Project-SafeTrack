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

// capaReadRoles lists roles allowed to read CAPA data.
// Field Reporters are excluded — they can only see incidents.
var capaReadRoles = []string{
	"safety_coordinator", "safety_manager", "pm", "division_manager", "executive", "admin",
}

// capaWriteRoles lists roles allowed to write CAPA data.
// Executive is read-only; Field Reporters are excluded entirely.
var capaWriteRoles = []string{
	"safety_coordinator", "safety_manager", "pm", "division_manager", "admin",
}

// RegisterCAPARoutes wires up all CAPA-related endpoints on the authenticated
// api mux. Field reporters are blocked from all CAPA endpoints (Issue 4).
func RegisterCAPARoutes(api *http.ServeMux, db *gorm.DB) {
	// Dashboard must be registered before the {id} routes to avoid
	// "dashboard" being captured as a path parameter.
	api.HandleFunc("GET /api/capas/dashboard", middleware.RequireRole(CAPADashboard(db), capaReadRoles...))

	// CRUD — read endpoints require at least safety_coordinator (or PM/DivMgr/Exec/Admin).
	api.HandleFunc("POST /api/capas", middleware.RequireRole(CreateCAPA(db), capaWriteRoles...))
	api.HandleFunc("GET /api/capas", middleware.RequireRole(ListCAPAs(db), capaReadRoles...))
	api.HandleFunc("GET /api/capas/{id}", middleware.RequireRole(GetCAPA(db), capaReadRoles...))
	api.HandleFunc("PUT /api/capas/{id}", middleware.RequireRole(UpdateCAPA(db), capaWriteRoles...))

	// Workflow
	api.HandleFunc("POST /api/capas/{id}/complete", middleware.RequireRole(CompleteCAPA(db), capaWriteRoles...))
	api.HandleFunc("POST /api/capas/{id}/verify", middleware.RequireRole(VerifyCAPA(db), capaWriteRoles...))
}

// ---------- helpers ----------

// capaDueDays returns the number of calendar days for the CAPA due date based
// on priority.
func capaDueDays(priority string) int {
	switch priority {
	case "Critical":
		return 7
	case "High":
		return 14
	case "Medium":
		return 30
	case "Low":
		return 60
	default:
		return 30 // safe default
	}
}

// capaVerificationDueDays returns the number of calendar days post-completion
// for the verification due date based on priority.
func capaVerificationDueDays(priority string) int {
	switch priority {
	case "Critical":
		return 30
	case "High":
		return 60
	default: // Medium, Low
		return 90
	}
}

// validCAPATypes enumerates allowed CAPA types.
var validCAPATypes = map[string]bool{
	"Corrective": true,
	"Preventive": true,
}

// validCAPACategories enumerates allowed CAPA categories.
var validCAPACategories = map[string]bool{
	"Training":               true,
	"Procedure Change":       true,
	"Engineering Control":    true,
	"PPE":                    true,
	"Equipment Modification": true,
	"Policy Change":          true,
	"Other":                  true,
}

// validCAPAPriorities enumerates allowed CAPA priorities.
var validCAPAPriorities = map[string]bool{
	"Critical": true,
	"High":     true,
	"Medium":   true,
	"Low":      true,
}

// updateCAPAOverdueStatus recalculates the IsOverdue flag and
// OverdueEscalationLevel for a CAPA. Call on GET requests for real-time
// accuracy.
func updateCAPAOverdueStatus(capa *models.CAPA) {
	terminalStatuses := map[string]bool{
		"Verified Effective":   true,
		"Verified Ineffective": true,
	}
	if terminalStatuses[capa.Status] {
		capa.IsOverdue = false
		capa.OverdueEscalationLevel = 0
		return
	}

	now := time.Now()

	// For Verification Pending, check VerificationDueDate.
	if capa.Status == "Verification Pending" && capa.VerificationDueDate != nil {
		if now.Before(*capa.VerificationDueDate) {
			capa.IsOverdue = false
			capa.OverdueEscalationLevel = 0
			return
		}
		capa.IsOverdue = true
		overdueDays := int(now.Sub(*capa.VerificationDueDate).Hours() / 24)
		capa.OverdueEscalationLevel = escalationLevel(overdueDays)
		return
	}

	// For Open / In Progress, check DueDate.
	if capa.Status == "Open" || capa.Status == "In Progress" {
		if now.Before(capa.DueDate) {
			capa.IsOverdue = false
			capa.OverdueEscalationLevel = 0
			return
		}
		capa.IsOverdue = true
		overdueDays := int(now.Sub(capa.DueDate).Hours() / 24)
		capa.OverdueEscalationLevel = escalationLevel(overdueDays)
		return
	}

	// Completed status (before verification) — not overdue on DueDate.
	capa.IsOverdue = false
	capa.OverdueEscalationLevel = 0
}

// escalationLevel maps the number of days overdue to an escalation level.
// 1-6 days = level 1, 7-13 days = level 2, 14+ days = level 3.
func escalationLevel(overdueDays int) int {
	switch {
	case overdueDays >= 14:
		return 3
	case overdueDays >= 7:
		return 2
	default:
		return 1
	}
}

// ---------- CRUD ----------

// createCAPARequest is the JSON body for POST /api/capas.
type createCAPARequest struct {
	InvestigationID    uint   `json:"investigationId"`
	IncidentID         uint   `json:"incidentId"`
	Type               string `json:"type"`
	Category           string `json:"category"`
	Description        string `json:"description"`
	AssignedToUserID   string `json:"assignedToUserId"`
	Priority           string `json:"priority"`
	VerificationMethod string `json:"verificationMethod"`
}

// CreateCAPA handles POST /api/capas.
// Auto-sets DueDate by priority, sets AssignedByUserID from auth context,
// updates incident status to "CAPA Assigned", and audit-logs.
// Executive role is blocked (read-only).
func CreateCAPA(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		// RBAC: Executive is read-only.
		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		var req createCAPARequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// Validate required fields.
		if req.InvestigationID == 0 || req.IncidentID == 0 {
			http.Error(w, "investigationId and incidentId are required", http.StatusBadRequest)
			return
		}
		if req.Description == "" || req.AssignedToUserID == "" {
			http.Error(w, "description and assignedToUserId are required", http.StatusBadRequest)
			return
		}
		if !validCAPATypes[req.Type] {
			http.Error(w, "type must be Corrective or Preventive", http.StatusBadRequest)
			return
		}
		if !validCAPACategories[req.Category] {
			http.Error(w, "invalid category", http.StatusBadRequest)
			return
		}
		if !validCAPAPriorities[req.Priority] {
			http.Error(w, "priority must be Critical, High, Medium, or Low", http.StatusBadRequest)
			return
		}

		// Verify investigation exists.
		var investigation models.Investigation
		if err := db.First(&investigation, req.InvestigationID).Error; err != nil {
			http.Error(w, "investigation not found", http.StatusNotFound)
			return
		}

		// Verify incident exists.
		var incident models.Incident
		if err := db.First(&incident, req.IncidentID).Error; err != nil {
			http.Error(w, "incident not found", http.StatusNotFound)
			return
		}

		now := time.Now()
		capa := models.CAPA{
			InvestigationID:    req.InvestigationID,
			IncidentID:         req.IncidentID,
			Type:               req.Type,
			Category:           req.Category,
			Description:        req.Description,
			AssignedToUserID:   req.AssignedToUserID,
			AssignedByUserID:   userID,
			DueDate:            now.AddDate(0, 0, capaDueDays(req.Priority)),
			Priority:           req.Priority,
			VerificationMethod: req.VerificationMethod,
			Status:             "Open",
		}

		if err := db.Create(&capa).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Update incident status to "CAPA Assigned" if applicable.
		if incident.Status == "Investigation Complete" {
			incidentBefore := toJSON(incident)
			incident.Status = "CAPA Assigned"
			if err := db.Save(&incident).Error; err != nil {
				http.Error(w, "database error updating incident status", http.StatusInternalServerError)
				return
			}
			LogAction(db, userID, userRole, "status_change", "incident", incident.ID, incidentBefore, toJSON(incident), "CAPA assigned", isAgent)
		}

		LogAction(db, userID, userRole, "create", "capa", capa.ID, "", toJSON(capa),
			fmt.Sprintf("CAPA created for investigation %d, incident %d", req.InvestigationID, req.IncidentID), isAgent)

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(capa)
	}
}

// ListCAPAs handles GET /api/capas with query filters.
// Supports: ?status=, ?assigned_to=, ?investigation_id=, ?incident_id=,
// ?overdue=true, ?priority=
// PM and Division Manager see scoped data via incident join.
func ListCAPAs(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := middleware.GetUserRole(r)

		query := db.Model(&models.CAPA{})

		// RBAC: PM scoped — only CAPAs for incidents on their projects.
		if userRole == "pm" {
			if project := middleware.GetUserProject(r); project != "" {
				query = query.Where("incident_id IN (SELECT id FROM incidents WHERE project_job_site = ?)", project)
			}
		}

		// RBAC: Division Manager scoped — only CAPAs for incidents in their division.
		if userRole == "division_manager" {
			if division := middleware.GetUserDivision(r); division != "" {
				query = query.Where("incident_id IN (SELECT id FROM incidents WHERE division = ?)", division)
			}
		}

		// Optional filters.
		if status := r.URL.Query().Get("status"); status != "" {
			query = query.Where("status = ?", status)
		}
		if assignedTo := r.URL.Query().Get("assigned_to"); assignedTo != "" {
			query = query.Where("assigned_to_user_id = ?", assignedTo)
		}
		if investigationID := r.URL.Query().Get("investigation_id"); investigationID != "" {
			query = query.Where("investigation_id = ?", investigationID)
		}
		if incidentID := r.URL.Query().Get("incident_id"); incidentID != "" {
			query = query.Where("incident_id = ?", incidentID)
		}
		if overdue := r.URL.Query().Get("overdue"); overdue == "true" {
			query = query.Where("is_overdue = ?", true)
		}
		if priority := r.URL.Query().Get("priority"); priority != "" {
			query = query.Where("priority = ?", priority)
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
			if v, err := strconv.Atoi(pp); err == nil && v > 0 && v <= 100 {
				perPage = v
			}
		}

		var total int64
		query.Count(&total)

		var capas []models.CAPA
		query.Order("created_at desc").
			Offset((page - 1) * perPage).
			Limit(perPage).
			Find(&capas)

		// Update overdue status in real-time for each result.
		for i := range capas {
			updateCAPAOverdueStatus(&capas[i])
			db.Model(&capas[i]).Updates(map[string]interface{}{
				"is_overdue":               capas[i].IsOverdue,
				"overdue_escalation_level": capas[i].OverdueEscalationLevel,
			})
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"data":     capas,
			"total":    total,
			"page":     page,
			"per_page": perPage,
		})
	}
}

// GetCAPA handles GET /api/capas/{id}.
// PM and Division Manager scope checks are enforced via the linked incident.
func GetCAPA(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := middleware.GetUserRole(r)

		id := r.PathValue("id")
		var capa models.CAPA
		if err := db.First(&capa, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// RBAC: PM/Division Manager scope check via linked incident.
		if userRole == "pm" || userRole == "division_manager" {
			var incident models.Incident
			if err := db.First(&incident, capa.IncidentID).Error; err != nil {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
			if userRole == "pm" {
				if project := middleware.GetUserProject(r); project != "" && incident.ProjectJobSite != project {
					http.Error(w, "forbidden", http.StatusForbidden)
					return
				}
			}
			if userRole == "division_manager" {
				if division := middleware.GetUserDivision(r); division != "" && incident.Division != division {
					http.Error(w, "forbidden", http.StatusForbidden)
					return
				}
			}
		}

		// Update overdue status in real-time.
		updateCAPAOverdueStatus(&capa)
		db.Model(&capa).Updates(map[string]interface{}{
			"is_overdue":               capa.IsOverdue,
			"overdue_escalation_level": capa.OverdueEscalationLevel,
		})

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(capa)
	}
}

// updateCAPARequest is the JSON body for PUT /api/capas/{id}.
type updateCAPARequest struct {
	Type               *string `json:"type"`
	Category           *string `json:"category"`
	Description        *string `json:"description"`
	AssignedToUserID   *string `json:"assignedToUserId"`
	Priority           *string `json:"priority"`
	VerificationMethod *string `json:"verificationMethod"`
	Status             *string `json:"status"`
}

// UpdateCAPA handles PUT /api/capas/{id}.
// When status changes to "In Progress", also updates parent incident status
// to "CAPA In Progress".
// Executive role is blocked (read-only).
func UpdateCAPA(db *gorm.DB) http.HandlerFunc {
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
		var existing models.CAPA
		if err := db.First(&existing, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		beforeJSON := toJSON(existing)

		var req updateCAPARequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// Apply partial updates.
		if req.Type != nil {
			if !validCAPATypes[*req.Type] {
				http.Error(w, "type must be Corrective or Preventive", http.StatusBadRequest)
				return
			}
			existing.Type = *req.Type
		}
		if req.Category != nil {
			if !validCAPACategories[*req.Category] {
				http.Error(w, "invalid category", http.StatusBadRequest)
				return
			}
			existing.Category = *req.Category
		}
		if req.Description != nil {
			existing.Description = *req.Description
		}
		if req.AssignedToUserID != nil {
			existing.AssignedToUserID = *req.AssignedToUserID
		}
		if req.Priority != nil {
			if !validCAPAPriorities[*req.Priority] {
				http.Error(w, "priority must be Critical, High, Medium, or Low", http.StatusBadRequest)
				return
			}
			existing.Priority = *req.Priority
			// Recalculate due date when priority changes.
			existing.DueDate = existing.CreatedAt.AddDate(0, 0, capaDueDays(*req.Priority))
		}
		if req.VerificationMethod != nil {
			existing.VerificationMethod = *req.VerificationMethod
		}

		oldStatus := existing.Status
		if req.Status != nil {
			existing.Status = *req.Status
		}

		if err := db.Save(&existing).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// When status changes to "In Progress", update incident status.
		if req.Status != nil && *req.Status == "In Progress" && oldStatus != "In Progress" {
			var incident models.Incident
			if err := db.First(&incident, existing.IncidentID).Error; err == nil {
				if incident.Status == "CAPA Assigned" {
					incidentBefore := toJSON(incident)
					incident.Status = "CAPA In Progress"
					if err := db.Save(&incident).Error; err == nil {
						LogAction(db, userID, userRole, "status_change", "incident", incident.ID,
							incidentBefore, toJSON(incident), "CAPA moved to In Progress", isAgent)
					}
				}
			}
		}

		LogAction(db, userID, userRole, "update", "capa", existing.ID, beforeJSON, toJSON(existing), "", isAgent)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(existing)
	}
}
