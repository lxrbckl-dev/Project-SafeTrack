package models

import "time"

// IncidentLink represents a manually created relationship between two incidents.
// Safety Coordinators can link incidents by similarity type with optional notes.
//
// The pair (IncidentID1, IncidentID2) is stored with the lower ID first to
// prevent duplicate rows in the unique constraint.
type IncidentLink struct {
	ID             uint      `gorm:"primaryKey"                          json:"id"`
	IncidentID1    uint      `gorm:"not null;index;uniqueIndex:uq_pair"  json:"incidentId1"`
	IncidentID2    uint      `gorm:"not null;index;uniqueIndex:uq_pair"  json:"incidentId2"`
	SimilarityType string    `gorm:"not null"                            json:"similarityType"` // Same Location, Same Type, Same Root Cause, Same Equipment, Same Person
	Notes          string    `gorm:"type:text"                           json:"notes"`
	LinkedByUserID string    `gorm:"not null"                            json:"linkedByUserId"`
	CreatedAt      time.Time `gorm:"autoCreateTime"                      json:"createdAt"`
}
