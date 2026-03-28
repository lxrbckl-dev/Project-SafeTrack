package models

import "time"

// HoursWorked tracks total man-hours per reporting period. Safety Managers
// enter these values so the dashboard can compute TRIR and DART rates.
type HoursWorked struct {
	ID                   uint      `gorm:"primaryKey" json:"id"`
	ReportingPeriodStart time.Time `gorm:"not null" json:"reportingPeriodStart"`
	ReportingPeriodEnd   time.Time `gorm:"not null" json:"reportingPeriodEnd"`
	TotalHours           float64   `gorm:"not null" json:"totalHours"`
	Division             string    `json:"division"`
	EnteredByUserID      string    `gorm:"not null" json:"enteredByUserId"`
	CreatedAt            time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt            time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}
