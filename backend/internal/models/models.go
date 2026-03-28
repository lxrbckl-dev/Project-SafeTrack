package models

// AllModels returns all database models for GORM auto-migration.
// Add new models here as you build features.
func AllModels() []interface{} {
	return []interface{}{
		&Note{},
		&AuditLog{},
		&Setting{},
		&Incident{},
		&InjuredPerson{},
		&IncidentPhoto{},
		&Investigation{},
		&FiveWhy{},
		&ContributingFactor{},
		&WitnessStatement{},
		&CAPA{},
		&HoursWorked{},
		&IncidentLink{},
		&Notification{},
	}
}
