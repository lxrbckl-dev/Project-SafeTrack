package models

import "time"

// IncidentPhoto stores a photo attachment for an incident. The raw file
// bytes are stored in FileData (bytea column) and excluded from JSON
// serialisation to keep list responses lightweight.
type IncidentPhoto struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	IncidentID  uint      `gorm:"not null;index" json:"incidentId"`
	FileName    string    `gorm:"not null" json:"fileName"`
	FileData    []byte    `gorm:"type:bytea" json:"-"` // excluded from JSON
	ContentType string    `json:"contentType"`
	UploadedBy  string    `json:"uploadedBy"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
}
