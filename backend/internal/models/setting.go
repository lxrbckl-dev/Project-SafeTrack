package models

import "time"

// Setting stores admin-configurable key-value pairs.
// Values are plain strings for scalar settings and JSON strings for
// complex settings (arrays, objects). Category is used for grouping
// in the UI.
type Setting struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Category  string    `gorm:"not null;index" json:"category"`
	Key       string    `gorm:"not null;uniqueIndex" json:"key"`
	Value     string    `gorm:"not null;type:text" json:"value"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
	UpdatedBy string    `json:"updatedBy"`
}
