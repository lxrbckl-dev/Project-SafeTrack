package models

import "time"

// InjuredPerson records details about an individual injured in an incident.
// Medical fields (InjuryType, BodyPart, TreatmentType, ReturnToWorkStatus)
// are encrypted at the application level before storage and decrypted only
// for users with Safety Coordinator role or above.
type InjuredPerson struct {
	ID                 uint      `gorm:"primaryKey" json:"id"`
	IncidentID         uint      `gorm:"not null;index" json:"incidentId"`
	Name               string    `gorm:"not null" json:"name"`
	JobTitle           string    `json:"jobTitle"`
	Division           string    `json:"division"`
	InjuryType         string    `json:"injuryType"` // ENCRYPTED
	BodyPart           string    `json:"bodyPart"`   // ENCRYPTED
	BodyPartSide       string    `json:"bodyPartSide"`
	TreatmentType      string    `json:"treatmentType"`      // ENCRYPTED
	ReturnToWorkStatus string    `json:"returnToWorkStatus"` // ENCRYPTED
	CreatedAt          time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt          time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}
