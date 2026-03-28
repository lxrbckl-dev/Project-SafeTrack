package models

import "time"

// ContributingFactor represents a factor that contributed to an incident,
// classified by a configurable FactorType from admin settings.
type ContributingFactor struct {
	ID                uint      `gorm:"primaryKey" json:"id"`
	InvestigationID   uint      `gorm:"not null;index" json:"investigationId"`
	FactorType        string    `gorm:"not null" json:"factorType"` // From configurable admin settings
	FactorDescription string    `gorm:"type:text" json:"factorDescription"`
	IsPrimary         bool      `gorm:"default:false" json:"isPrimary"`
	CreatedAt         time.Time `gorm:"autoCreateTime" json:"createdAt"`
}
