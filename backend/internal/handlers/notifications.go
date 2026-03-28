package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
	"github.com/lxRbckl/highlander/backend/internal/services"
)

// RegisterNotificationRoutes wires up all notification-related endpoints on
// the authenticated api mux.
func RegisterNotificationRoutes(api *http.ServeMux, db *gorm.DB) {
	// check-escalations must be registered before {id} routes to prevent
	// "check-escalations" being captured as a path parameter.
	api.HandleFunc("POST /api/notifications/check-escalations", CheckEscalations(db))
	api.HandleFunc("GET /api/notifications", ListNotifications(db))
	api.HandleFunc("PUT /api/notifications/{id}/read", MarkNotificationRead(db))

	// Notification preference endpoints
	api.HandleFunc("GET /api/users/me/notification-preferences", GetNotificationPreferences(db))
	api.HandleFunc("PUT /api/users/{id}/notification-preferences", UpdateNotificationPreferences(db))
}

// ---------- CRUD ----------

// ListNotifications handles GET /api/notifications.
// Returns notifications for the current authenticated user.
// Optional filter: ?unread=true — returns only unread notifications.
func ListNotifications(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)

		query := db.Model(&models.Notification{}).
			Where("user_id = ?", userID)

		if r.URL.Query().Get("unread") == "true" {
			query = query.Where("is_read = ?", false)
		}

		var notifications []models.Notification
		if err := query.Order("created_at desc").Find(&notifications).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(notifications)
	}
}

// MarkNotificationRead handles PUT /api/notifications/{id}/read.
// Marks a single notification as read. Only allows the owning user to update.
func MarkNotificationRead(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		id := r.PathValue("id")

		var notification models.Notification
		if err := db.First(&notification, id).Error; err != nil {
			http.Error(w, "notification not found", http.StatusNotFound)
			return
		}

		// Only the owning user may mark their notification read.
		if notification.UserID != userID {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		if err := db.Model(&notification).Update("is_read", true).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		notification.IsRead = true
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(notification)
	}
}

// ---------- Notification Preferences ----------

// notificationPreferenceRequest is the JSON body for updating preferences.
type notificationPreferenceRequest struct {
	Preference string `json:"preference"` // in_app_only, email, both
}

// notificationPreferenceResponse is the JSON response for preference endpoints.
type notificationPreferenceResponse struct {
	UserID     string `json:"userId"`
	Preference string `json:"preference"`
}

// validPreferences are the allowed notification preference values.
var validPreferences = map[string]bool{
	"in_app_only": true,
	"email":       true,
	"both":        true,
}

// GetNotificationPreferences handles GET /api/users/me/notification-preferences.
// Returns the current user's notification preference.
func GetNotificationPreferences(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)

		var user models.User
		if err := db.First(&user, userID).Error; err != nil {
			http.Error(w, "user not found", http.StatusNotFound)
			return
		}

		pref := user.NotificationPreference
		if pref == "" {
			pref = "both"
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(notificationPreferenceResponse{
			UserID:     userID,
			Preference: pref,
		})
	}
}

// UpdateNotificationPreferences handles PUT /api/users/{id}/notification-preferences.
// Updates a user's notification preference. Users can only update their own preference,
// unless they are an admin.
func UpdateNotificationPreferences(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		callerID := middleware.GetUserID(r)
		callerRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)
		targetID := r.PathValue("id")

		// Users can only update their own preferences unless admin.
		if callerID != targetID && callerRole != "admin" {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		var req notificationPreferenceRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if !validPreferences[req.Preference] {
			http.Error(w, "invalid preference: must be in_app_only, email, or both", http.StatusBadRequest)
			return
		}

		var user models.User
		if err := db.First(&user, targetID).Error; err != nil {
			http.Error(w, "user not found", http.StatusNotFound)
			return
		}

		if err := db.Model(&user).Update("notification_preference", req.Preference).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, callerID, callerRole, "update", "user", user.ID, "", fmt.Sprintf(`{"notificationPreference":"%s"}`, req.Preference), "notification preference updated", isAgent)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(notificationPreferenceResponse{
			UserID:     targetID,
			Preference: req.Preference,
		})
	}
}

// ---------- Escalation check ----------

// CheckEscalations handles POST /api/notifications/check-escalations.
//
// This endpoint scans all active investigations and CAPAs for overdue items
// and creates in-app Notification records for affected users at the +3, +7,
// and +14 day escalation thresholds. It also checks railroad notification
// deadlines and creates notifications for overdue railroad notifications.
//
// When a notification is created, an email is also sent if the user's
// notification preference allows it (preference "email" or "both").
//
// Idempotent: a notification is only created once per
// (entityType, entityID, type, escalation level) combination — duplicate
// checks are skipped.
//
// Callers: a background job, cron, or the admin can POST to this endpoint to
// trigger a sweep. No request body is required.
func CheckEscalations(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		role := middleware.GetUserRole(r)
		if role != "safety_manager" && role != "admin" {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		created := 0
		emailsSent := 0

		nc, ne := checkInvestigationEscalations(db)
		created += nc
		emailsSent += ne

		nc, ne = checkCAPAEscalations(db)
		created += nc
		emailsSent += ne

		nc, ne = checkRailroadEscalations(db)
		created += nc
		emailsSent += ne

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"notificationsCreated": created,
			"emailsSent":           emailsSent,
			"checkedAt":            time.Now().UTC(),
		})
	}
}

// ---------- internal escalation logic ----------

// escalationThresholds are the overdue day milestones at which a notification
// is created. These map directly to OverdueEscalationLevel values.
var escalationThresholds = []struct {
	days  int
	level int
}{
	{days: 3, level: 1},
	{days: 7, level: 2},
	{days: 14, level: 3},
}

// notificationExists returns true if a notification already exists for the
// given user, entity, type, and escalation level combination.
// Uses a proper keyed unique check on entity_type + entity_id + type + escalation_level.
func notificationExists(db *gorm.DB, userID string, notifType string, entityType string, entityID uint, level int) bool {
	var count int64
	db.Model(&models.Notification{}).
		Where("user_id = ? AND type = ? AND entity_type = ? AND entity_id = ? AND escalation_level = ?",
			userID, notifType, entityType, entityID, level).
		Count(&count)
	return count > 0
}

// escalationTitleSuffix returns the suffix used in notification titles to
// identify which escalation threshold fired.
func escalationTitleSuffix(level int) string {
	switch level {
	case 1:
		return "(+3 days)"
	case 2:
		return "(+7 days)"
	case 3:
		return "(+14 days)"
	default:
		return ""
	}
}

// createNotification inserts a new Notification record. Returns 1 on success, 0 on failure.
// level is the escalation threshold level (0 = no threshold, 1/2/3 = +3/+7/+14 days).
// When preference is "in_app_only", only the in-app notification is created (no email).
// When preference is "email", only the email is sent (the in-app notification is still
// stored so the bell badge works). When preference is "both", both are created.
func createNotification(db *gorm.DB, userID, title, message, notifType, entityType string, entityID uint, level int) int {
	n := models.Notification{
		UserID:          userID,
		Title:           title,
		Message:         message,
		Type:            notifType,
		EntityType:      entityType,
		EntityID:        entityID,
		EscalationLevel: level,
		IsRead:          false,
	}
	if err := db.Create(&n).Error; err != nil {
		return 0
	}

	// Broadcast notification event to WebSocket clients for real-time bell badge.
	if wsHub != nil {
		wsHub.Broadcast(WSEvent{
			Type: "notification",
			Data: map[string]interface{}{
				"id":         n.ID,
				"userId":     n.UserID,
				"title":      n.Title,
				"message":    n.Message,
				"type":       n.Type,
				"entityType": n.EntityType,
				"entityId":   n.EntityID,
				"isRead":     n.IsRead,
				"createdAt":  n.CreatedAt,
			},
		})
	}

	return 1
}

// shouldSendEmail checks the user's notification preference and returns true
// if the preference is "email" or "both". Looks up the user by ID string.
func shouldSendEmail(db *gorm.DB, userID string) bool {
	uid, err := strconv.ParseUint(userID, 10, 64)
	if err != nil {
		return false
	}
	var user models.User
	if err := db.First(&user, uid).Error; err != nil {
		return false
	}
	pref := user.NotificationPreference
	if pref == "" {
		pref = "both" // default
	}
	return pref == "email" || pref == "both"
}

// getUserEmail looks up the user's email address by ID string.
func getUserEmail(db *gorm.DB, userID string) string {
	uid, err := strconv.ParseUint(userID, 10, 64)
	if err != nil {
		return ""
	}
	var user models.User
	if err := db.Select("email").First(&user, uid).Error; err != nil {
		return ""
	}
	return user.Email
}

// trySendEmail attempts to send an email notification, returning 1 if sent, 0 otherwise.
// It checks the user's preference before sending.
func trySendEmail(db *gorm.DB, userID string, sendFunc func(email string) error) int {
	if !shouldSendEmail(db, userID) {
		return 0
	}
	email := getUserEmail(db, userID)
	if email == "" {
		return 0
	}
	if err := sendFunc(email); err != nil {
		log.Printf("[notifications] Email send failed for user %s: %v", userID, err)
		return 0
	}
	return 1
}

// checkInvestigationEscalations scans open investigations for overdue items
// and fires notifications at +3, +7, +14 day thresholds.
// Notifies the lead investigator and the assigner (Safety Manager).
// Returns (notificationsCreated, emailsSent).
func checkInvestigationEscalations(db *gorm.DB) (int, int) {
	// Only non-terminal investigations.
	var investigations []models.Investigation
	db.Where("status NOT IN ?", []string{"Approved", "Returned"}).Find(&investigations)

	now := time.Now()
	created := 0
	emails := 0

	for _, inv := range investigations {
		if now.Before(inv.TargetCompletionDate) {
			continue // not overdue yet
		}

		overdueDays := int(now.Sub(inv.TargetCompletionDate).Hours() / 24)
		targetDateStr := inv.TargetCompletionDate.Format("Jan 2, 2006")

		for _, threshold := range escalationThresholds {
			if overdueDays < threshold.days {
				continue
			}

			suffix := escalationTitleSuffix(threshold.level)
			title := fmt.Sprintf("Overdue Investigation %s", suffix)
			message := fmt.Sprintf(
				"Investigation #%d is %d days past its target completion date of %s.",
				inv.ID,
				overdueDays,
				targetDateStr,
			)

			// Notify lead investigator.
			if inv.LeadInvestigatorID != "" &&
				!notificationExists(db, inv.LeadInvestigatorID, "overdue_investigation", "investigation", inv.ID, threshold.level) {
				created += createNotification(db, inv.LeadInvestigatorID, title, message, "overdue_investigation", "investigation", inv.ID, threshold.level)
				emails += trySendEmail(db, inv.LeadInvestigatorID, func(email string) error {
					return services.SendOverdueInvestigationEmail(email, inv.ID, overdueDays, targetDateStr)
				})
			}

			// Notify the assigner (Safety Manager who created the investigation).
			if inv.AssignedBy != "" && inv.AssignedBy != inv.LeadInvestigatorID &&
				!notificationExists(db, inv.AssignedBy, "overdue_investigation", "investigation", inv.ID, threshold.level) {
				created += createNotification(db, inv.AssignedBy, title, message, "overdue_investigation", "investigation", inv.ID, threshold.level)
				emails += trySendEmail(db, inv.AssignedBy, func(email string) error {
					return services.SendOverdueInvestigationEmail(email, inv.ID, overdueDays, targetDateStr)
				})
			}
		}
	}

	return created, emails
}

// checkCAPAEscalations scans open CAPAs for overdue items and fires
// notifications at +3, +7, +14 day thresholds.
// Notifies the assigned user and the assigner.
// Returns (notificationsCreated, emailsSent).
func checkCAPAEscalations(db *gorm.DB) (int, int) {
	// Only actionable CAPAs: overdue due date for Open/In Progress,
	// overdue verification due date for Verification Pending.
	// Completed and terminal statuses are excluded.
	var capas []models.CAPA
	db.Where("status IN ?", []string{"Open", "In Progress", "Verification Pending"}).Find(&capas)

	now := time.Now()
	created := 0
	emails := 0

	for _, capa := range capas {
		// Choose the relevant deadline based on current status.
		var deadline time.Time
		switch capa.Status {
		case "Verification Pending":
			if capa.VerificationDueDate == nil {
				continue
			}
			deadline = *capa.VerificationDueDate
		default: // Open, In Progress
			deadline = capa.DueDate
		}

		if now.Before(deadline) {
			continue // not overdue yet
		}

		overdueDays := int(now.Sub(deadline).Hours() / 24)
		dueDateStr := deadline.Format("Jan 2, 2006")

		for _, threshold := range escalationThresholds {
			if overdueDays < threshold.days {
				continue
			}

			suffix := escalationTitleSuffix(threshold.level)
			title := fmt.Sprintf("Overdue CAPA %s", suffix)
			message := fmt.Sprintf(
				"CAPA #%d (%s priority) is %d days past its due date of %s.",
				capa.ID,
				capa.Priority,
				overdueDays,
				dueDateStr,
			)

			// Notify the assigned user.
			if capa.AssignedToUserID != "" &&
				!notificationExists(db, capa.AssignedToUserID, "overdue_capa", "capa", capa.ID, threshold.level) {
				created += createNotification(db, capa.AssignedToUserID, title, message, "overdue_capa", "capa", capa.ID, threshold.level)
				emails += trySendEmail(db, capa.AssignedToUserID, func(email string) error {
					return services.SendOverdueCAPAEmail(email, capa.ID, capa.Priority, overdueDays, dueDateStr)
				})
			}

			// Notify the assigning user (Safety Coordinator/Manager).
			if capa.AssignedByUserID != "" && capa.AssignedByUserID != capa.AssignedToUserID &&
				!notificationExists(db, capa.AssignedByUserID, "overdue_capa", "capa", capa.ID, threshold.level) {
				created += createNotification(db, capa.AssignedByUserID, title, message, "overdue_capa", "capa", capa.ID, threshold.level)
				emails += trySendEmail(db, capa.AssignedByUserID, func(email string) error {
					return services.SendOverdueCAPAEmail(email, capa.ID, capa.Priority, overdueDays, dueDateStr)
				})
			}
		}
	}

	return created, emails
}

// checkRailroadEscalations scans railroad-property incidents where the
// required client notification is overdue and creates notifications for
// the incident reporter.
// Returns (notificationsCreated, emailsSent).
func checkRailroadEscalations(db *gorm.DB) (int, int) {
	// Find railroad-property incidents that have not been notified.
	var incidents []models.Incident
	db.Where("is_railroad_property = ? AND railroad_notified = ?", true, false).Find(&incidents)

	created := 0
	emails := 0

	for _, incident := range incidents {
		if !CheckRailroadNotificationOverdue(&incident) {
			continue
		}

		// Only create one railroad notification per incident (level 0 sentinel).
		if notificationExists(db, incident.ReporterID, "railroad_notification", "incident", incident.ID, 0) {
			continue
		}

		title := "Railroad Notification Overdue"
		message := fmt.Sprintf(
			"Incident #%d on %s railroad property requires client notification (%s) that is now overdue.",
			incident.ID,
			incident.RailroadClient,
			incident.Type,
		)

		created += createNotification(db, incident.ReporterID, title, message, "railroad_notification", "incident", incident.ID, 0)
		emails += trySendEmail(db, incident.ReporterID, func(email string) error {
			return services.SendRailroadDeadlineEmail(email, incident.ID, incident.RailroadClient, incident.Type)
		})
	}

	return created, emails
}
