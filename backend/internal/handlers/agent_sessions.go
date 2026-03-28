package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// activeSessionWindow is the look-back period used to determine whether an
// agent key counts as an "active session". This is a display heuristic only —
// agents do not maintain persistent connections (except WebSocket).
const activeSessionWindow = 5 * time.Minute

// agentSessionItem is the response shape for GET /api/agent/sessions.
type agentSessionItem struct {
	KeyID      uint       `json:"keyId"`
	KeyPrefix  string     `json:"keyPrefix"`
	KeyName    string     `json:"keyName"`
	UserID     uint       `json:"userId"`
	UserName   string     `json:"userName"`
	UserRole   string     `json:"userRole"`
	LastUsedAt *time.Time `json:"lastUsedAt"`
}

// agentActivityItem is the response shape for GET /api/agent/activity.
type agentActivityItem struct {
	ID              uint      `json:"id"`
	Timestamp       time.Time `json:"timestamp"`
	UserDisplayName string    `json:"userDisplayName"`
	UserRole        string    `json:"userRole"`
	Message         string    `json:"message"`
	EntityType      string    `json:"entityType"`
	EntityID        uint      `json:"entityId"`
	Action          string    `json:"action"`
}

// GetAgentSessions handles GET /api/agent/sessions.
//
// Admin only. Returns all active agent API keys whose LastUsedAt falls within
// the last 5 minutes. Edge case: multiple keys for the same user appear as
// separate entries, each identified by KeyID.
func GetAgentSessions(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if role := middleware.GetUserRole(r); role != "admin" {
			http.Error(w, "forbidden: Admin only", http.StatusForbidden)
			return
		}

		cutoff := time.Now().Add(-activeSessionWindow)

		// Join with users to get display name and role.
		// Multiple keys for the same user each appear as separate rows (edge case 1).
		var keys []models.AgentApiKey
		if err := db.Preload("User").
			Where("is_active = ? AND last_used_at >= ?", true, cutoff).
			Order("last_used_at desc").
			Find(&keys).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		items := make([]agentSessionItem, len(keys))
		for i, k := range keys {
			items[i] = agentSessionItem{
				KeyID:      k.ID,
				KeyPrefix:  k.KeyPrefix,
				KeyName:    k.Name,
				UserID:     k.UserID,
				UserName:   k.User.DisplayName,
				UserRole:   k.User.Role,
				LastUsedAt: k.LastUsedAt,
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(items)
	}
}

// GetAgentActivity handles GET /api/agent/activity.
//
// Returns audit log entries where is_agent=true. Applies the same RBAC
// scoping as the regular activity feed (edge case: division/project scoping
// for PM and Division Manager). Supports cursor-based pagination via `since`
// (RFC3339) and `limit` (default 50, max 200) to handle high-volume agent
// audit logs without OOM (edge case: cursor pagination).
//
// Edge case: rejection and rollback actions are included — the filter is on
// is_agent only, so all action types (create, reject, rollback, etc.) appear.
func GetAgentActivity(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		// Build query filtered to agent-only entries, newest first.
		query := db.Model(&models.AuditLog{}).
			Where("is_agent = ?", true).
			Order("timestamp desc")

		// Cursor-based pagination: `since` acts as a cursor on the timestamp
		// index. This is O(log n) regardless of table size, unlike offset
		// pagination which degrades to O(n) for deep pages.
		if sinceStr := r.URL.Query().Get("since"); sinceStr != "" {
			t, err := time.Parse(time.RFC3339, sinceStr)
			if err != nil {
				http.Error(w, "invalid 'since' parameter, expected RFC3339", http.StatusBadRequest)
				return
			}
			query = query.Where("timestamp > ?", t)
		}

		// Limit — default 50, max 200 (higher than regular feed because agents
		// generate more events per time window).
		limit := 50
		if l := r.URL.Query().Get("limit"); l != "" {
			var v int
			if _, err2 := fmt.Sscanf(l, "%d", &v); err2 == nil && v > 0 && v <= 200 {
				limit = v
			}
		}

		// Apply the same RBAC scoping as the regular activity feed so that
		// division-scoped and project-scoped users see only their slice of
		// agent activity (edge case: division scoping on agent activity).
		query = applyActivityRBAC(query, userID, userRole, r)

		query = query.Limit(limit)

		var logs []models.AuditLog
		if err := query.Find(&logs).Error; err != nil {
			http.Error(w, "failed to fetch agent activity", http.StatusInternalServerError)
			return
		}

		displayNames := buildDisplayNameMap(db, logs)

		items := make([]agentActivityItem, 0, len(logs))
		for _, l := range logs {
			name := displayNames[l.UserID]
			if name == "" {
				name = l.UserID
			}
			items = append(items, agentActivityItem{
				ID:              l.ID,
				Timestamp:       l.Timestamp,
				UserDisplayName: name,
				UserRole:        l.UserRole,
				Message:         buildActivityMessage(name, l),
				EntityType:      l.EntityType,
				EntityID:        l.EntityID,
				Action:          l.Action,
			})
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(items)
	}
}

// RegisterAgentSessionRoutes wires up agent session and activity endpoints.
// Called from main.go under the authenticated mux.
func RegisterAgentSessionRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("GET /api/agent/sessions", GetAgentSessions(db))
	api.HandleFunc("GET /api/agent/activity", GetAgentActivity(db))
}
