package models

import "time"

type Note struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Content   string    `gorm:"not null" json:"content"`
	CreatedAt time.Time `json:"createdAt"`
}
