package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// ActivityFeedItem is a human-readable representation of an audit log entry
// for display in the live activity feed.
type ActivityFeedItem struct {
	ID              uint      `json:"id"`
	Timestamp       time.Time `json:"timestamp"`
	UserDisplayName string    `json:"userDisplayName"`
	UserRole        string    `json:"userRole"`
	Message         string    `json:"message"`
	EntityType      string    `json:"entityType"`
	EntityID        uint      `json:"entityId"`
	Action          string    `json:"action"`
}

// RegisterActivityRoutes registers the activity feed endpoint.
func RegisterActivityRoutes(mux *http.ServeMux, db *gorm.DB) {
	mux.HandleFunc("GET /api/activity", GetActivityFeed(db))
}

// GetActivityFeed returns recent audit log entries formatted as human-readable
// feed items. RBAC-scoped: users only see activity for entities they can access.
//
// Query params:
//   - since: RFC3339 timestamp — returns items after this time
//   - limit: max items to return (default 50, max 100)
func GetActivityFeed(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		// Build the audit log query, newest first.
		query := db.Model(&models.AuditLog{}).Order("timestamp desc")

		// Filter by timestamp if provided.
		var sinceTime *time.Time
		if sinceStr := r.URL.Query().Get("since"); sinceStr != "" {
			t, err := time.Parse(time.RFC3339, sinceStr)
			if err != nil {
				http.Error(w, "invalid 'since' parameter, expected RFC3339 format", http.StatusBadRequest)
				return
			}
			sinceTime = &t
		}
		if sinceTime != nil {
			query = query.Where("timestamp > ?", sinceTime)
		}

		// Limit results.
		limit := 50
		if l := r.URL.Query().Get("limit"); l != "" {
			var v int
			if _, err := fmt.Sscanf(l, "%d", &v); err == nil && v > 0 && v <= 100 {
				limit = v
			}
		}

		// RBAC scoping: filter audit logs based on user role.
		// We join against the incidents table for incident-related entries
		// to enforce the same visibility rules as the incident list endpoint.
		query = applyActivityRBAC(query, userID, userRole, r)

		query = query.Limit(limit)

		var logs []models.AuditLog
		if err := query.Find(&logs).Error; err != nil {
			http.Error(w, "failed to fetch activity feed", http.StatusInternalServerError)
			return
		}

		// Look up display names for all unique user IDs.
		displayNames := buildDisplayNameMap(db, logs)

		// Convert to feed items.
		items := make([]ActivityFeedItem, 0, len(logs))
		for _, log := range logs {
			name := displayNames[log.UserID]
			if name == "" {
				name = log.UserID
			}

			items = append(items, ActivityFeedItem{
				ID:              log.ID,
				Timestamp:       log.Timestamp,
				UserDisplayName: name,
				UserRole:        log.UserRole,
				Message:         buildActivityMessage(name, log),
				EntityType:      log.EntityType,
				EntityID:        log.EntityID,
				Action:          log.Action,
			})
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(items)
	}
}

// applyActivityRBAC applies role-based visibility filters to the audit log
// query. This mirrors the RBAC logic from the incident, investigation, and
// CAPA list endpoints:
//   - Draft incidents: only visible to the reporter
//   - PM: only sees entities in their project
//   - Division Manager: only sees entities in their division
//   - All others: see all non-draft entries
func applyActivityRBAC(query *gorm.DB, userID, userRole string, r *http.Request) *gorm.DB {
	// Exclude audit entries for draft incidents unless the user is the reporter.
	// We subquery against the incidents table to check draft status.
	query = query.Where(
		"(entity_type != 'incident' OR entity_id NOT IN (SELECT id FROM incidents WHERE is_draft = true AND reporter_id != ?))",
		userID,
	)

	// PM scoped: only show activity for incidents/investigations/capas in their project.
	if userRole == "pm" {
		if project := middleware.GetUserProject(r); project != "" {
			query = query.Where(
				"("+
					"(entity_type = 'incident' AND entity_id IN (SELECT id FROM incidents WHERE project_job_site = ?))"+
					" OR (entity_type = 'investigation' AND entity_id IN (SELECT id FROM investigations WHERE incident_id IN (SELECT id FROM incidents WHERE project_job_site = ?)))"+
					" OR (entity_type = 'capa' AND entity_id IN (SELECT id FROM capas WHERE incident_id IN (SELECT id FROM incidents WHERE project_job_site = ?)))"+
					" OR entity_type NOT IN ('incident', 'investigation', 'capa')"+
					")",
				project, project, project,
			)
		}
	}

	// Division Manager scoped: only show activity for entities in their division.
	if userRole == "division_manager" {
		if division := middleware.GetUserDivision(r); division != "" {
			query = query.Where(
				"("+
					"(entity_type = 'incident' AND entity_id IN (SELECT id FROM incidents WHERE division = ?))"+
					" OR (entity_type = 'investigation' AND entity_id IN (SELECT id FROM investigations WHERE incident_id IN (SELECT id FROM incidents WHERE division = ?)))"+
					" OR (entity_type = 'capa' AND entity_id IN (SELECT id FROM capas WHERE incident_id IN (SELECT id FROM incidents WHERE division = ?)))"+
					" OR entity_type NOT IN ('incident', 'investigation', 'capa')"+
					")",
				division, division, division,
			)
		}
	}

	// Exclude settings changes from non-admin users (internal admin actions).
	if userRole != "admin" && userRole != "safety_manager" {
		query = query.Where("entity_type != 'setting'")
	}

	return query
}

// buildDisplayNameMap fetches User records for all unique user IDs in the
// log entries and returns a map of userID → displayName.
func buildDisplayNameMap(db *gorm.DB, logs []models.AuditLog) map[string]string {
	// Collect unique user IDs.
	idSet := make(map[string]bool)
	for _, l := range logs {
		idSet[l.UserID] = true
	}
	if len(idSet) == 0 {
		return nil
	}

	ids := make([]string, 0, len(idSet))
	for id := range idSet {
		ids = append(ids, id)
	}

	var users []models.User
	db.Where("email IN ?", ids).Find(&users)

	nameMap := make(map[string]string, len(users))
	for _, u := range users {
		nameMap[u.Email] = u.DisplayName
	}
	return nameMap
}

// buildActivityMessage generates a human-readable message from an audit log entry.
func buildActivityMessage(displayName string, log models.AuditLog) string {
	entityLabel := formatEntityType(log.EntityType)

	switch log.Action {
	case "create":
		return buildCreateMessage(displayName, log, entityLabel)
	case "approve":
		return fmt.Sprintf("%s approved %s #%d", displayName, entityLabel, log.EntityID)
	case "reject":
		return fmt.Sprintf("%s rejected %s #%d", displayName, entityLabel, log.EntityID)
	case "complete":
		return fmt.Sprintf("%s completed %s #%d", displayName, entityLabel, log.EntityID)
	case "verify":
		return buildVerifyMessage(displayName, log, entityLabel)
	case "assign":
		return fmt.Sprintf("%s assigned %s #%d", displayName, entityLabel, log.EntityID)
	case "status_change":
		return fmt.Sprintf("%s updated the status of %s #%d", displayName, entityLabel, log.EntityID)
	case "update":
		return fmt.Sprintf("%s updated %s #%d", displayName, entityLabel, log.EntityID)
	default:
		return fmt.Sprintf("%s performed %s on %s #%d", displayName, log.Action, entityLabel, log.EntityID)
	}
}

// buildCreateMessage produces a human-readable "create" message with
// additional context for specific entity types.
func buildCreateMessage(displayName string, log models.AuditLog, entityLabel string) string {
	switch log.EntityType {
	case "incident":
		// Try to extract incident type from the After JSON snapshot.
		incidentType := extractJSONField(log.After, "incidentType")
		if incidentType != "" {
			return fmt.Sprintf("%s reported a %s incident", displayName, formatIncidentType(incidentType))
		}
		return fmt.Sprintf("%s reported an incident", displayName)
	case "investigation":
		return fmt.Sprintf("%s assigned %s #%d", displayName, entityLabel, log.EntityID)
	case "link":
		// For link creation, try to extract linked entity IDs.
		sourceID := extractJSONField(log.After, "incidentId")
		linkedID := extractJSONField(log.After, "linkedIncidentId")
		if sourceID != "" && linkedID != "" {
			return fmt.Sprintf("%s linked Incident #%s to Incident #%s", displayName, sourceID, linkedID)
		}
		return fmt.Sprintf("%s created a link between incidents", displayName)
	default:
		return fmt.Sprintf("%s created %s #%d", displayName, entityLabel, log.EntityID)
	}
}

// buildVerifyMessage produces a human-readable "verify" message that includes
// whether the verification was effective or ineffective.
func buildVerifyMessage(displayName string, log models.AuditLog, entityLabel string) string {
	effectiveness := extractJSONField(log.After, "verificationResult")
	if effectiveness == "" {
		effectiveness = extractJSONField(log.After, "effectiveness")
	}
	if effectiveness != "" {
		return fmt.Sprintf("%s verified %s #%d as %s", displayName, entityLabel, log.EntityID, effectiveness)
	}
	return fmt.Sprintf("%s verified %s #%d", displayName, entityLabel, log.EntityID)
}

// formatEntityType converts an entity_type string to a human-readable label.
func formatEntityType(entityType string) string {
	switch entityType {
	case "incident":
		return "Incident"
	case "investigation":
		return "Investigation"
	case "capa":
		return "CAPA"
	case "link":
		return "Link"
	case "setting":
		return "Setting"
	case "training":
		return "Training"
	default:
		if entityType == "" {
			return "Entity"
		}
		return strings.ToUpper(entityType[:1]) + entityType[1:]
	}
}

// formatIncidentType converts an incident type enum to a human-readable label.
func formatIncidentType(incidentType string) string {
	switch incidentType {
	case "near_miss":
		return "Near Miss"
	case "injury_illness":
		return "Injury/Illness"
	case "property_damage":
		return "Property Damage"
	case "environmental":
		return "Environmental"
	default:
		return strings.ReplaceAll(incidentType, "_", " ")
	}
}

// extractJSONField tries to extract a string field from a JSON string.
// Returns empty string on failure.
func extractJSONField(jsonStr, field string) string {
	if jsonStr == "" {
		return ""
	}
	var data map[string]interface{}
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		return ""
	}
	if v, ok := data[field]; ok {
		return fmt.Sprintf("%v", v)
	}
	return ""
}
