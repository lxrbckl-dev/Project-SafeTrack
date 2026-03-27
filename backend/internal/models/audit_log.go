package models

import "time"

// AuditLog is an append-only record of every action taken on incidents,
// investigations, and CAPAs. Records are never updated or deleted.
type AuditLog struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	Timestamp  time.Time `gorm:"autoCreateTime;index" json:"timestamp"`
	UserID     string    `gorm:"not null;index" json:"userId"`
	UserRole   string    `gorm:"not null" json:"userRole"`
	Action     string    `gorm:"not null" json:"action"`           // create, update, status_change, approve, reject, assign, verify
	EntityType string    `gorm:"not null;index" json:"entityType"` // incident, investigation, capa, setting
	EntityID   uint      `gorm:"not null;index" json:"entityId"`
	Before     string    `gorm:"type:text" json:"before"` // JSON snapshot before change (empty on create)
	After      string    `gorm:"type:text" json:"after"`  // JSON snapshot after change
	Notes      string    `gorm:"type:text" json:"notes"`  // Optional context (e.g., rejection reason)
}
