package models

import "time"

// TrainingCompletion records the completion of a TrainingRequirement.
// One-to-one relationship: each TrainingRequirement has at most one completion.
type TrainingCompletion struct {
	ID                    uint      `gorm:"primaryKey" json:"id"`
	TrainingRequirementID uint      `gorm:"not null;uniqueIndex" json:"trainingRequirementId"`
	CompletedByUserID     string    `gorm:"not null" json:"completedByUserId"`
	CompletionDate        time.Time `gorm:"not null" json:"completionDate"`
	DurationHours         float64   `json:"durationHours"`
	InstructorName        string    `json:"instructorName"`
	Notes                 string    `gorm:"type:text" json:"notes"`
	Evidence              string    `gorm:"type:text" json:"evidence"`
	VerifiedByUserID      string    `json:"verifiedByUserId"`
	CreatedAt             time.Time `gorm:"autoCreateTime" json:"createdAt"`
}
