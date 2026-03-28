package models

import "time"

// FiveWhy represents a single Why/Answer pair in a 5-Why root cause analysis.
// Each investigation requires a minimum of 3 five-why entries before submission.
type FiveWhy struct {
	ID              uint      `gorm:"primaryKey" json:"id"`
	InvestigationID uint      `gorm:"not null;index" json:"investigationId"`
	Level           int       `gorm:"not null" json:"level"`
	Question        string    `gorm:"not null;type:text" json:"question"`
	Answer          string    `gorm:"not null;type:text" json:"answer"`
	Evidence        string    `gorm:"type:text" json:"evidence"`
	SortOrder       int       `gorm:"not null" json:"sortOrder"`
	CreatedAt       time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt       time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}
