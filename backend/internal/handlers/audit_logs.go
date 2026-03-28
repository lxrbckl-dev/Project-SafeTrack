package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// wsHub is a package-level reference to the WebSocket hub. When non-nil,
// LogAction will broadcast activity events to all connected clients.
// Set via SetWSHub during server startup.
var wsHub *Hub

// SetWSHub stores a reference to the WebSocket hub so that LogAction can
// broadcast real-time events. Must be called once during server startup.
func SetWSHub(h *Hub) {
	wsHub = h
}

// LogAction creates an immutable audit log entry. Call this from any handler
// that creates, updates, or changes the status of an entity.
//
// When a WebSocket hub is configured (via SetWSHub), this also broadcasts
// an "activity" event to connected clients so they get real-time updates
// without polling.
func LogAction(db *gorm.DB, userID, userRole, action, entityType string, entityID uint, before, after, notes string, isAgent bool) error {
	entry := models.AuditLog{
		UserID:     userID,
		UserRole:   userRole,
		Action:     action,
		EntityType: entityType,
		EntityID:   entityID,
		Before:     before,
		After:      after,
		Notes:      notes,
		IsAgent:    isAgent,
	}
	if err := db.Create(&entry).Error; err != nil {
		return err
	}

	// Broadcast to WebSocket clients if hub is available.
	if wsHub != nil {
		wsHub.Broadcast(WSEvent{
			Type: "activity",
			Data: map[string]interface{}{
				"id":         entry.ID,
				"timestamp":  entry.Timestamp,
				"userId":     entry.UserID,
				"userRole":   entry.UserRole,
				"action":     entry.Action,
				"entityType": entry.EntityType,
				"entityId":   entry.EntityID,
				"notes":      entry.Notes,
				"isAgent":    entry.IsAgent,
			},
		})
	}

	return nil
}

// GetAuditLogs returns paginated audit log entries, newest first.
// RBAC: Admin and Safety Manager only.
// Query params: ?entity_type=incident&entity_id=5&user_id=dev-admin
//
//	&action=create&date_start=2025-01-01&date_end=2025-12-31
//	&page=1&per_page=50
func GetAuditLogs(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// RBAC: only Admin and Safety Manager can view audit logs
		role := middleware.GetUserRole(r)
		if role != "admin" && role != "safety_manager" {
			http.Error(w, "forbidden: audit log access restricted to Admin and Safety Manager", http.StatusForbidden)
			return
		}

		query := db.Model(&models.AuditLog{}).Order("timestamp desc")

		if et := r.URL.Query().Get("entity_type"); et != "" {
			query = query.Where("entity_type = ?", et)
		}
		if eid := r.URL.Query().Get("entity_id"); eid != "" {
			query = query.Where("entity_id = ?", eid)
		}
		if uid := r.URL.Query().Get("user_id"); uid != "" {
			query = query.Where("user_id = ?", uid)
		}
		if action := r.URL.Query().Get("action"); action != "" {
			query = query.Where("action = ?", action)
		}
		if ds := r.URL.Query().Get("date_start"); ds != "" {
			if t, err := time.Parse("2006-01-02", ds); err == nil {
				query = query.Where("timestamp >= ?", t)
			}
		}
		if de := r.URL.Query().Get("date_end"); de != "" {
			if t, err := time.Parse("2006-01-02", de); err == nil {
				// Include the entire end day by advancing to start of next day
				query = query.Where("timestamp < ?", t.AddDate(0, 0, 1))
			}
		}

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

		var logs []models.AuditLog
		query.Offset((page - 1) * perPage).Limit(perPage).Find(&logs)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"data":     logs,
			"total":    total,
			"page":     page,
			"per_page": perPage,
		})
	}
}
