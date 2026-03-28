package models

import "time"

// AgentApiKey stores a bcrypt-hashed API key that external agents use to
// authenticate against the system. The full key is returned exactly once at
// creation time and never stored in plaintext.
type AgentApiKey struct {
	ID         uint       `gorm:"primaryKey" json:"id"`
	UserID     uint       `gorm:"not null;index" json:"userId"`     // FK to User
	KeyHash    string     `gorm:"not null" json:"-"`                // bcrypt hash — never exposed
	KeyPrefix  string     `gorm:"not null;size:8" json:"keyPrefix"` // first 8 chars for display (e.g., "stk_abc1")
	Name       string     `gorm:"not null" json:"name"`             // user-given label (e.g., "OpenClaw agent")
	IsActive   bool       `gorm:"not null;default:true" json:"isActive"`
	LastUsedAt *time.Time `json:"lastUsedAt"`
	CreatedAt  time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	RevokedAt  *time.Time `json:"revokedAt"`

	// Navigation: load the associated User when needed.
	User User `gorm:"foreignKey:UserID" json:"user,omitempty"`
}
