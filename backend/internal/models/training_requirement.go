package models

import "time"

// TrainingRequirement represents a training course linked to a Training-category CAPA.
// When a CAPA with Category="Training" is created, a TrainingRequirement is
// auto-created with the same due date and assignee.
type TrainingRequirement struct {
	ID               uint      `gorm:"primaryKey" json:"id"`
	CAPAID           uint      `gorm:"not null;index" json:"capaId"`
	CourseName       string    `gorm:"not null" json:"courseName"`
	Description      string    `gorm:"type:text" json:"description"`
	AssignedToUserID string    `gorm:"not null;index" json:"assignedToUserId"`
	AssignedByUserID string    `gorm:"not null" json:"assignedByUserId"`
	DueDate          time.Time `gorm:"not null" json:"dueDate"`
	Status           string    `gorm:"not null;default:'Pending';index" json:"status"` // Pending, Completed
	CreatedAt        time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt        time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}
