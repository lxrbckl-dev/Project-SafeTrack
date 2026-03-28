package models

import "time"

// User represents an authenticated application user with role-based access.
// Passwords are stored as bcrypt hashes and never exposed via JSON.
type User struct {
	ID                     uint      `gorm:"primaryKey" json:"id"`
	Email                  string    `gorm:"not null;uniqueIndex" json:"email"`
	PasswordHash           string    `gorm:"not null" json:"-"` // Never expose in JSON
	DisplayName            string    `gorm:"not null" json:"displayName"`
	Role                   string    `gorm:"not null;index" json:"role"`
	Division               string    `json:"division"`
	Project                string    `json:"project"`
	NotificationPreference string    `gorm:"not null;default:'both'" json:"notificationPreference"` // in_app_only, email, both
	CreatedAt              time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt              time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}
