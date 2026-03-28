package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/models"
)

// TimelineEvent is a single chronological event in an incident's lifecycle.
// It aggregates audit log entries from the incident itself, its linked
// investigation, and all CAPAs — enriched with a human-readable description
// and the actor's display name resolved from the User table.
type TimelineEvent struct {
	Timestamp       string `json:"timestamp"`
	Action          string `json:"action"`
	UserDisplayName string `json:"userDisplayName"`
	UserRole        string `json:"userRole"`
	Description     string `json:"description"`
	EntityType      string `json:"entityType"`
	EntityID        uint   `json:"entityId"`
}

// GetIncidentTimeline handles GET /api/incidents/{id}/timeline.
// It collects audit log entries for the incident, its investigation, and all
// CAPAs, then returns them sorted chronologically (oldest first).
// No RBAC restriction — any authenticated user who can view the incident may
// view its timeline.
func GetIncidentTimeline(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Extract incident ID from URL path: /api/incidents/{id}/timeline
		path := r.URL.Path
		// Path is expected to end with "/<id>/timeline"
		path = strings.TrimSuffix(path, "/timeline")
		parts := strings.Split(path, "/")
		rawID := parts[len(parts)-1]
		incidentID, err := strconv.ParseUint(rawID, 10, 64)
		if err != nil || incidentID == 0 {
			http.Error(w, "invalid incident id", http.StatusBadRequest)
			return
		}
		iID := uint(incidentID)

		// Build a user display name lookup cache keyed by UserID string.
		userCache := make(map[string]string)
		resolveUser := func(userID string) string {
			if name, ok := userCache[userID]; ok {
				return name
			}
			var u models.User
			if err := db.Where("id = ?", userID).First(&u).Error; err == nil {
				userCache[userID] = u.DisplayName
				return u.DisplayName
			}
			// Fall back to the user ID itself if not found.
			userCache[userID] = userID
			return userID
		}

		var allLogs []models.AuditLog

		// 1. Audit logs directly on the incident.
		var incidentLogs []models.AuditLog
		db.Where("entity_type = ? AND entity_id = ?", "incident", iID).
			Find(&incidentLogs)
		allLogs = append(allLogs, incidentLogs...)

		// 2. Investigation audit logs (fetch investigation by incident_id first).
		var investigation models.Investigation
		if err := db.Where("incident_id = ?", iID).First(&investigation).Error; err == nil {
			var invLogs []models.AuditLog
			db.Where("entity_type = ? AND entity_id = ?", "investigation", investigation.ID).
				Find(&invLogs)
			allLogs = append(allLogs, invLogs...)
		}

		// 3. CAPA audit logs (fetch all CAPAs by incident_id first).
		var capas []models.CAPA
		db.Where("incident_id = ?", iID).Find(&capas)
		for _, capa := range capas {
			var capaLogs []models.AuditLog
			db.Where("entity_type = ? AND entity_id = ?", "capa", capa.ID).
				Find(&capaLogs)
			allLogs = append(allLogs, capaLogs...)
		}

		// Sort all logs chronologically — oldest first.
		sort.Slice(allLogs, func(i, j int) bool {
			return allLogs[i].Timestamp.Before(allLogs[j].Timestamp)
		})

		// Map logs to TimelineEvent DTOs.
		events := make([]TimelineEvent, 0, len(allLogs))
		for _, log := range allLogs {
			events = append(events, TimelineEvent{
				Timestamp:       log.Timestamp.UTC().Format("2006-01-02T15:04:05Z"),
				Action:          log.Action,
				UserDisplayName: resolveUser(log.UserID),
				UserRole:        log.UserRole,
				Description:     buildDescription(log),
				EntityType:      log.EntityType,
				EntityID:        log.EntityID,
			})
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(events)
	}
}

// buildDescription converts an audit log entry into a concise human-readable
// sentence that is displayed in the timeline widget.
func buildDescription(log models.AuditLog) string {
	entity := entityLabel(log.EntityType, log.EntityID)
	switch log.Action {
	case "create":
		return fmt.Sprintf("%s reported", entity)
	case "update":
		return fmt.Sprintf("%s updated", entity)
	case "status_change":
		// Try to extract the new status from the Notes or After field.
		if log.Notes != "" {
			return fmt.Sprintf("%s status changed: %s", entity, log.Notes)
		}
		if log.After != "" {
			return fmt.Sprintf("%s status changed", entity)
		}
		return fmt.Sprintf("%s status changed", entity)
	case "approve":
		return fmt.Sprintf("%s approved", entity)
	case "reject":
		if log.Notes != "" {
			return fmt.Sprintf("%s returned: %s", entity, log.Notes)
		}
		return fmt.Sprintf("%s returned for revision", entity)
	case "assign":
		return fmt.Sprintf("%s assigned", entity)
	case "verify":
		if log.Notes != "" {
			return fmt.Sprintf("%s verified: %s", entity, log.Notes)
		}
		return fmt.Sprintf("%s verified effective", entity)
	case "escalation":
		return fmt.Sprintf("%s escalated", entity)
	default:
		return fmt.Sprintf("%s — %s", entity, log.Action)
	}
}

// entityLabel returns a human-readable name for a given entity type.
func entityLabel(entityType string, entityID uint) string {
	switch entityType {
	case "incident":
		return "Incident"
	case "investigation":
		return "Investigation"
	case "capa":
		return fmt.Sprintf("CAPA #%d", entityID)
	default:
		return strings.Title(entityType) //nolint:staticcheck // acceptable for display label
	}
}

// RegisterIncidentTimelineRoutes registers the timeline route on the given mux.
func RegisterIncidentTimelineRoutes(mux *http.ServeMux, db *gorm.DB) {
	mux.HandleFunc("GET /api/incidents/{id}/timeline", GetIncidentTimeline(db))
}
