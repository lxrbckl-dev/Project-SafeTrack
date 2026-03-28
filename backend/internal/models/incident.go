package models

import "time"

// Incident represents a safety incident report. It supports draft saving,
// OSHA recordability determination, railroad notification tracking, and
// a full lifecycle from Reported through Closed.
type Incident struct {
	ID                          uint            `gorm:"primaryKey" json:"id"`
	Type                        string          `gorm:"not null;index" json:"type"` // Injury, Near Miss, Property Damage, Environmental, Vehicle, Fire, Utility Strike
	Date                        time.Time       `gorm:"not null" json:"date"`
	Location                    string          `gorm:"not null" json:"location"`
	Latitude                    float64         `json:"latitude"`
	Longitude                   float64         `json:"longitude"`
	Division                    string          `gorm:"index" json:"division"`
	ProjectJobSite              string          `json:"projectJobSite"`
	Description                 string          `gorm:"not null;type:text" json:"description"`
	ImmediateActions            string          `gorm:"type:text" json:"immediateActions"`
	Severity                    string          `json:"severity"`
	PotentialSeverity           string          `json:"potentialSeverity"`
	Shift                       string          `json:"shift"`
	Weather                     string          `json:"weather"`
	Status                      string          `gorm:"not null;default:'Draft';index" json:"status"`
	ReporterID                  string          `gorm:"not null;index" json:"reporterId"`
	IsDraft                     bool            `gorm:"default:true" json:"isDraft"`
	CompletionPercent           int             `json:"completionPercent"`
	IsOshaRecordable            *bool           `json:"isOshaRecordable"`
	IsDart                      *bool           `json:"isDart"`
	OshaOverrideJustification   string          `gorm:"type:text" json:"oshaOverrideJustification"`
	IsRailroadProperty          bool            `json:"isRailroadProperty"`
	RailroadClient              string          `json:"railroadClient"` // BNSF, UP, CSX, NS
	RailroadNotified            bool            `json:"railroadNotified"`
	RailroadNotificationDate    *time.Time      `json:"railroadNotificationDate"`
	RailroadNotificationMethod  string          `json:"railroadNotificationMethod"`
	RailroadNotificationOverdue bool            `json:"railroadNotificationOverdue"`
	InjuredPersons              []InjuredPerson `gorm:"foreignKey:IncidentID" json:"injuredPersons,omitempty"`
	Photos                      []IncidentPhoto `gorm:"foreignKey:IncidentID" json:"photos,omitempty"`
	CreatedAt                   time.Time       `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt                   time.Time       `gorm:"autoUpdateTime" json:"updatedAt"`
}
