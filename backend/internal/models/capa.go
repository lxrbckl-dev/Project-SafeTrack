package models

import "time"

// CAPA represents a Corrective and Preventive Action linked to an
// investigation and its parent incident. It tracks the full CAPA lifecycle
// from creation through verification of effectiveness.
type CAPA struct {
	ID                     uint       `gorm:"primaryKey" json:"id"`
	InvestigationID        uint       `gorm:"not null;index" json:"investigationId"`
	IncidentID             uint       `gorm:"not null;index" json:"incidentId"`
	Type                   string     `gorm:"not null" json:"type"`     // Corrective, Preventive
	Category               string     `gorm:"not null" json:"category"` // Training, Procedure Change, Engineering Control, PPE, Equipment Modification, Policy Change, Other
	Description            string     `gorm:"not null;type:text" json:"description"`
	AssignedToUserID       string     `gorm:"not null;index" json:"assignedToUserId"`
	AssignedByUserID       string     `gorm:"not null" json:"assignedByUserId"`
	DueDate                time.Time  `gorm:"not null" json:"dueDate"`
	Priority               string     `gorm:"not null;index" json:"priority"` // Critical, High, Medium, Low
	VerificationMethod     string     `gorm:"type:text" json:"verificationMethod"`
	VerificationDueDate    *time.Time `json:"verificationDueDate"`
	Status                 string     `gorm:"not null;default:'Open';index" json:"status"` // Open, In Progress, Completed, Verification Pending, Verified Effective, Verified Ineffective
	CompletionNotes        string     `gorm:"type:text" json:"completionNotes"`
	CompletionEvidence     string     `gorm:"type:text" json:"completionEvidence"`
	CompletionDate         *time.Time `json:"completionDate"`
	VerifiedByUserID       string     `json:"verifiedByUserId"`
	VerificationDate       *time.Time `json:"verificationDate"`
	VerificationNotes      string     `gorm:"type:text" json:"verificationNotes"`
	IsOverdue              bool       `json:"isOverdue"`
	OverdueEscalationLevel int        `json:"overdueEscalationLevel"` // 0=not overdue, 1=1-6 days, 2=7-13 days, 3=14+ days
	CreatedAt              time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt              time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`
}
