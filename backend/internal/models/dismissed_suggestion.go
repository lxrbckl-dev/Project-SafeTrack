package models

import "time"

// DismissedSuggestion records that a user has dismissed a recurrence
// suggestion for a particular incident pair. This prevents the suggestion
// from being shown again.
type DismissedSuggestion struct {
	ID                  uint      `gorm:"primaryKey"                                             json:"id"`
	IncidentID          uint      `gorm:"not null;index;uniqueIndex:uq_dismissed_pair"           json:"incidentId"`
	SuggestedIncidentID uint      `gorm:"not null;uniqueIndex:uq_dismissed_pair"                 json:"suggestedIncidentId"`
	DismissedByUserID   string    `gorm:"not null;uniqueIndex:uq_dismissed_pair"                 json:"dismissedByUserId"`
	CreatedAt           time.Time `gorm:"autoCreateTime"                                         json:"createdAt"`
}
