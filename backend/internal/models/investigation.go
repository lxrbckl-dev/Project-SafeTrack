package models

import "time"

// Investigation represents a safety investigation linked to a single incident.
// It tracks the investigation lifecycle from assignment through review/approval.
type Investigation struct {
	ID                     uint                 `gorm:"primaryKey" json:"id"`
	IncidentID             uint                 `gorm:"not null;uniqueIndex" json:"incidentId"`
	LeadInvestigatorID     string               `gorm:"not null" json:"leadInvestigatorId"`
	TeamMembers            string               `gorm:"type:text" json:"teamMembers"` // JSON array of user IDs
	TargetCompletionDate   time.Time            `json:"targetCompletionDate"`
	ActualCompletionDate   *time.Time           `json:"actualCompletionDate"`
	Status                 string               `gorm:"not null;default:'Assigned';index" json:"status"` // Assigned, In Progress, Under Review, Approved, Returned
	AssignedBy             string               `gorm:"not null" json:"assignedBy"`
	ReviewedBy             string               `json:"reviewedBy"`
	ReviewComments         string               `gorm:"type:text" json:"reviewComments"`
	ReviewDate             *time.Time           `json:"reviewDate"`
	IsOverdue              bool                 `json:"isOverdue"`
	OverdueEscalationLevel int                  `json:"overdueEscalationLevel"` // 0=not overdue, 1=1-3 days, 2=4-7 days, 3=8+ days
	FiveWhys               []FiveWhy            `gorm:"foreignKey:InvestigationID" json:"fiveWhys,omitempty"`
	ContributingFactors    []ContributingFactor `gorm:"foreignKey:InvestigationID" json:"contributingFactors,omitempty"`
	WitnessStatements      []WitnessStatement   `gorm:"foreignKey:InvestigationID" json:"witnessStatements,omitempty"`
	CreatedAt              time.Time            `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt              time.Time            `gorm:"autoUpdateTime" json:"updatedAt"`
}
