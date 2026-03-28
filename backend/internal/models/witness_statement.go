package models

import "time"

// WitnessStatement captures a witness account related to an investigation,
// including the witness's contact details and the statement text.
type WitnessStatement struct {
	ID              uint      `gorm:"primaryKey" json:"id"`
	InvestigationID uint      `gorm:"not null;index" json:"investigationId"`
	WitnessName     string    `gorm:"not null" json:"witnessName"`
	WitnessTitle    string    `json:"witnessTitle"`
	WitnessEmployer string    `json:"witnessEmployer"`
	WitnessPhone    string    `json:"witnessPhone"`
	StatementText   string    `gorm:"not null;type:text" json:"statementText"`
	CollectionDate  time.Time `json:"collectionDate"`
	CollectorName   string    `json:"collectorName"`
	CreatedAt       time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt       time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}
