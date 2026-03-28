package models

import "time"

// Notification represents an in-app escalation or system notification for a
// specific user. Notifications are created by the check-escalations endpoint
// and displayed in the UI notification panel.
//
// Type values:
//   - overdue_investigation — investigation has passed its target completion date
//   - overdue_capa          — CAPA has passed its due or verification due date
//   - railroad_notification — railroad incident notification is overdue
//   - review_request        — investigation submitted for Safety Manager review
type Notification struct {
	ID              uint      `gorm:"primaryKey" json:"id"`
	UserID          string    `gorm:"not null;index" json:"userId"`
	Title           string    `gorm:"not null" json:"title"`
	Message         string    `gorm:"not null;type:text" json:"message"`
	Type            string    `gorm:"not null;index" json:"type"` // overdue_investigation, overdue_capa, railroad_notification, review_request
	EntityType      string    `gorm:"not null" json:"entityType"` // incident, investigation, capa
	EntityID        uint      `gorm:"not null" json:"entityId"`
	EscalationLevel int       `gorm:"not null;default:0" json:"escalationLevel"`
	IsRead          bool      `gorm:"default:false;index" json:"isRead"`
	CreatedAt       time.Time `gorm:"autoCreateTime" json:"createdAt"`
}
