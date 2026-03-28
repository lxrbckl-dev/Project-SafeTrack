package handlers

import (
	"time"

	"github.com/lxRbckl/highlander/backend/internal/models"
)

// railroadDeadline defines the notification deadline in hours for a given
// incident type on a specific railroad client's property.
type railroadDeadline struct {
	Injury         float64 // hours (0 = immediately)
	NearMiss       float64
	PropertyDamage float64
}

// deadlines encodes the per-railroad notification rules from the rubric.
//
//	BNSF: Injury 2h, Near Miss 24h, Property Damage 4h
//	UP:   Injury immediately (0h), Near Miss 24h, Property Damage 2h
//	CSX:  Injury 1h, Near Miss within shift (12h), Property Damage 1h
//	NS:   Injury 2h, Near Miss 24h, Property Damage 2h
var deadlines = map[string]railroadDeadline{
	"BNSF": {Injury: 2, NearMiss: 24, PropertyDamage: 4},
	"UP":   {Injury: 0, NearMiss: 24, PropertyDamage: 2},
	"CSX":  {Injury: 1, NearMiss: 12, PropertyDamage: 1},
	"NS":   {Injury: 2, NearMiss: 24, PropertyDamage: 2},
}

// CheckRailroadNotificationOverdue determines whether the railroad client
// notification deadline has been exceeded for the given incident.
//
// It compares CreatedAt + deadline hours against the current time. If the
// incident has already been notified (RailroadNotified == true) or the
// railroad client is unknown, it returns false.
func CheckRailroadNotificationOverdue(incident *models.Incident) bool {
	if incident.RailroadNotified {
		return false
	}

	dl, ok := deadlines[incident.RailroadClient]
	if !ok {
		return false
	}

	var hours float64
	switch incident.Type {
	case "Injury":
		hours = dl.Injury
	case "Near Miss":
		hours = dl.NearMiss
	case "Property Damage":
		hours = dl.PropertyDamage
	default:
		// For other incident types (Environmental, Vehicle, Fire, Utility Strike)
		// there are no railroad-specific deadlines defined in the rubric.
		return false
	}

	// Special case: "immediately" (0 hours) means the deadline is already
	// passed as soon as the incident is created.
	if hours == 0 {
		return true
	}

	deadline := incident.CreatedAt.Add(time.Duration(hours * float64(time.Hour)))
	return time.Now().After(deadline)
}
