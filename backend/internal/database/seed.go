// Package database provides the PostgreSQL connection setup and seed data for demo.
package database

import (
	"fmt"
	"log"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/crypto"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// SeedData populates the database with realistic demo data.
// It is idempotent — if any incidents already exist, it returns immediately.
// Trigger by setting SEED_DATA=true in the environment.
func SeedData(db *gorm.DB) {
	var count int64
	db.Model(&models.Incident{}).Count(&count)
	if count > 0 {
		log.Println("Seed: incidents table is non-empty — skipping seed")
		return
	}

	log.Println("Seed: populating demo data…")

	now := time.Now()

	// -------------------------------------------------------------------------
	// Helpers
	// -------------------------------------------------------------------------
	timePtr := func(t time.Time) *time.Time { return &t }

	mustEncrypt := func(plain string) string {
		enc, err := crypto.Encrypt(plain)
		if err != nil {
			panic(fmt.Sprintf("seed encrypt: %v", err))
		}
		return enc
	}

	// -------------------------------------------------------------------------
	// Admin Settings — skip if already seeded by TASK-003
	// -------------------------------------------------------------------------
	var settingCount int64
	db.Model(&models.Setting{}).Count(&settingCount)
	if settingCount == 0 {
		settings := []models.Setting{
			{Category: "safety", Key: "trir_benchmark", Value: "3.0", UpdatedBy: "dev-admin"},
			{Category: "safety", Key: "factor_types_list", Value: `["People","Equipment","Environmental","Procedural","Management/Organizational"]`, UpdatedBy: "dev-admin"},
			{Category: "notifications", Key: "escalation_days", Value: `[3,7,14]`, UpdatedBy: "dev-admin"},
		}
		db.Create(&settings)
	}

	// -------------------------------------------------------------------------
	// Hours Worked — 12 months of data (approx 500,000 hours/year total)
	// Spread across 3 divisions for TRIR/DART calculations.
	// -------------------------------------------------------------------------
	divisions := []string{"Construction", "Maintenance", "Operations"}
	hoursPerDivisionPerMonth := 13_889.0 // ~500k / 12 / 3 = ~13,889 h/month per division

	for monthOffset := 11; monthOffset >= 0; monthOffset-- {
		periodStart := now.AddDate(0, -monthOffset-1, 0)
		periodStart = time.Date(periodStart.Year(), periodStart.Month(), 1, 0, 0, 0, 0, time.UTC)
		periodEnd := periodStart.AddDate(0, 1, 0).Add(-time.Second)

		for _, div := range divisions {
			db.Create(&models.HoursWorked{
				ReportingPeriodStart: periodStart,
				ReportingPeriodEnd:   periodEnd,
				TotalHours:           hoursPerDivisionPerMonth,
				Division:             div,
				EnteredByUserID:      "dev-safety_manager",
			})
		}
	}

	// -------------------------------------------------------------------------
	// Incidents (18 total)
	// -------------------------------------------------------------------------
	trueVal := true
	falseVal := false

	incidents := []*models.Incident{
		// 1. Injury — Closed, OSHA recordable, DART
		{
			Type:               "Injury",
			Date:               now.AddDate(0, -11, 5),
			Location:           "Main Yard, Track 3",
			Latitude:           41.8781,
			Longitude:          -87.6298,
			Division:           "Construction",
			ProjectJobSite:     "Project Alpha",
			Description:        "Worker sustained a laceration to the left hand while operating a cutting tool without proper PPE.",
			ImmediateActions:   "First aid applied on-site. Worker transported to urgent care. Area secured.",
			Severity:           "High",
			PotentialSeverity:  "Critical",
			Shift:              "Day",
			Weather:            "Clear",
			Status:             "Closed",
			ReporterID:         "dev-field_reporter",
			IsDraft:            false,
			CompletionPercent:  100,
			IsOshaRecordable:   &trueVal,
			IsDart:             &trueVal,
			IsRailroadProperty: false,
		},
		// 2. Near Miss — Under Investigation
		{
			Type:               "Near Miss",
			Date:               now.AddDate(0, -8, -3),
			Location:           "North Bridge Construction Zone",
			Latitude:           41.8850,
			Longitude:          -87.6150,
			Division:           "Construction",
			ProjectJobSite:     "Project Beta",
			Description:        "Worker nearly struck by swinging crane load. Load was improperly secured.",
			ImmediateActions:   "Crane operations halted. Load secured. Supervisor notified.",
			Severity:           "High",
			PotentialSeverity:  "Catastrophic",
			Shift:              "Day",
			Weather:            "Cloudy",
			Status:             "Under Investigation",
			ReporterID:         "dev-field_reporter_2",
			IsDraft:            false,
			CompletionPercent:  75,
			IsOshaRecordable:   &falseVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
		// 3. Property Damage — CAPA In Progress, railroad (BNSF), notified
		{
			Type:                        "Property Damage",
			Date:                        now.AddDate(0, -6, 10),
			Location:                    "BNSF Subdivision MP 214",
			Latitude:                    41.9000,
			Longitude:                   -87.7000,
			Division:                    "Maintenance",
			ProjectJobSite:              "Project Gamma",
			Description:                 "Excavator bucket contacted buried fiber-optic conduit, damaging approximately 30 ft of cable.",
			ImmediateActions:            "Excavation stopped. BNSF notified within 2 hours. Area cordoned.",
			Severity:                    "Medium",
			PotentialSeverity:           "High",
			Shift:                       "Day",
			Weather:                     "Clear",
			Status:                      "CAPA In Progress",
			ReporterID:                  "dev-field_reporter",
			IsDraft:                     false,
			CompletionPercent:           85,
			IsOshaRecordable:            &falseVal,
			IsDart:                      &falseVal,
			IsRailroadProperty:          true,
			RailroadClient:              "BNSF",
			RailroadNotified:            true,
			RailroadNotificationDate:    timePtr(now.AddDate(0, -6, 10).Add(90 * time.Minute)),
			RailroadNotificationMethod:  "Phone",
			RailroadNotificationOverdue: false,
		},
		// 4. Environmental — Reported
		{
			Type:               "Environmental",
			Date:               now.AddDate(0, -4, 2),
			Location:           "South Yard Fuel Storage Area",
			Latitude:           41.8700,
			Longitude:          -87.6400,
			Division:           "Operations",
			ProjectJobSite:     "Project Alpha",
			Description:        "Approximately 5 gallons of diesel fuel spilled during refueling operations. Reached storm drain.",
			ImmediateActions:   "Spill contained with absorbent booms. Environmental team notified. Drain plugged.",
			Severity:           "Medium",
			PotentialSeverity:  "High",
			Shift:              "Evening",
			Weather:            "Rain",
			Status:             "Reported",
			ReporterID:         "dev-field_reporter_3",
			IsDraft:            false,
			CompletionPercent:  55,
			IsRailroadProperty: false,
		},
		// 5. Vehicle — Investigation Complete
		{
			Type:               "Vehicle",
			Date:               now.AddDate(0, -7, -5),
			Location:           "Site Access Road, Gate 2",
			Latitude:           41.8820,
			Longitude:          -87.6320,
			Division:           "Construction",
			ProjectJobSite:     "Project Beta",
			Description:        "Company pickup truck backed into a parked equipment trailer. Trailer hitch damaged bumper.",
			ImmediateActions:   "Vehicles moved. Damage photographed. Supervisor notified.",
			Severity:           "Low",
			PotentialSeverity:  "Medium",
			Shift:              "Day",
			Weather:            "Clear",
			Status:             "Investigation Complete",
			ReporterID:         "dev-field_reporter_2",
			IsDraft:            false,
			CompletionPercent:  90,
			IsOshaRecordable:   &falseVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
		// 6. Fire — Closed
		{
			Type:               "Fire",
			Date:               now.AddDate(0, -10, 15),
			Location:           "Welding Station B, Shop Building",
			Latitude:           41.8760,
			Longitude:          -87.6350,
			Division:           "Maintenance",
			ProjectJobSite:     "Project Gamma",
			Description:        "Welding spark ignited cardboard debris near workstation. Fire extinguished within 2 minutes.",
			ImmediateActions:   "Fire extinguished with CO2 extinguisher. Area evacuated briefly. Hot work permit reviewed.",
			Severity:           "Medium",
			PotentialSeverity:  "High",
			Shift:              "Day",
			Weather:            "Clear",
			Status:             "Closed",
			ReporterID:         "dev-field_reporter",
			IsDraft:            false,
			CompletionPercent:  100,
			IsOshaRecordable:   &falseVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
		// 7. Utility Strike — CAPA Assigned, railroad (UP), overdue notification
		{
			Type:                        "Utility Strike",
			Date:                        now.AddDate(0, -3, 8),
			Location:                    "UP Mainline near MP 87, Trenching Area",
			Latitude:                    41.9200,
			Longitude:                   -87.7200,
			Division:                    "Construction",
			ProjectJobSite:              "Project Gamma",
			Description:                 "Trenching crew struck an unmarked gas line at 4 ft depth. No ignition. Gas company called immediately.",
			ImmediateActions:            "Excavation halted. Area evacuated. Gas company and UP notified. Line marked and capped.",
			Severity:                    "Critical",
			PotentialSeverity:           "Catastrophic",
			Shift:                       "Day",
			Weather:                     "Clear",
			Status:                      "CAPA Assigned",
			ReporterID:                  "dev-field_reporter_3",
			IsDraft:                     false,
			CompletionPercent:           80,
			IsOshaRecordable:            &trueVal,
			IsDart:                      &falseVal,
			IsRailroadProperty:          true,
			RailroadClient:              "UP",
			RailroadNotified:            false,
			RailroadNotificationOverdue: true,
		},
		// 8. Injury — Under Investigation, 2nd injured person, OSHA recordable
		{
			Type:               "Injury",
			Date:               now.AddDate(0, -5, -2),
			Location:           "Elevated Work Platform, Zone C",
			Latitude:           41.8810,
			Longitude:          -87.6270,
			Division:           "Maintenance",
			ProjectJobSite:     "Project Alpha",
			Description:        "Worker fell from scaffold at 8 ft elevation. Sustained fractured wrist and bruised ribs. Second worker on platform experienced minor ankle sprain.",
			ImmediateActions:   "911 called. Both workers transported to hospital. Scaffold work halted. Area secured.",
			Severity:           "Critical",
			PotentialSeverity:  "Catastrophic",
			Shift:              "Day",
			Weather:            "Windy",
			Status:             "Under Investigation",
			ReporterID:         "dev-field_reporter",
			IsDraft:            false,
			CompletionPercent:  70,
			IsOshaRecordable:   &trueVal,
			IsDart:             &trueVal,
			IsRailroadProperty: false,
		},
		// 9. Near Miss — Draft (only visible to reporter)
		{
			Type:               "Near Miss",
			Date:               now.AddDate(0, 0, -2),
			Location:           "Stockpile Area, Lot 7",
			Division:           "Operations",
			ProjectJobSite:     "Project Beta",
			Description:        "Forklift came within 2 ft of pedestrian zone boundary without horn signal.",
			ImmediateActions:   "Operator reminded of pedestrian zone rules.",
			Severity:           "Low",
			PotentialSeverity:  "High",
			Shift:              "Day",
			Weather:            "Clear",
			Status:             "Draft",
			ReporterID:         "dev-field_reporter_2",
			IsDraft:            true,
			CompletionPercent:  30,
			IsRailroadProperty: false,
		},
		// 10. Property Damage — Reported
		{
			Type:               "Property Damage",
			Date:               now.AddDate(0, -2, 5),
			Location:           "Equipment Yard, Bay 4",
			Latitude:           41.8740,
			Longitude:          -87.6290,
			Division:           "Maintenance",
			ProjectJobSite:     "Project Alpha",
			Description:        "Overhead crane cable snapped, dropping a 500lb beam onto an empty flatbed trailer. No injuries.",
			ImmediateActions:   "Area cleared. Crane locked out. Maintenance team called.",
			Severity:           "Medium",
			PotentialSeverity:  "Critical",
			Shift:              "Night",
			Weather:            "Clear",
			Status:             "Reported",
			ReporterID:         "dev-field_reporter_3",
			IsDraft:            false,
			CompletionPercent:  60,
			IsRailroadProperty: false,
		},
		// 11. Environmental — CAPA In Progress
		{
			Type:               "Environmental",
			Date:               now.AddDate(0, -9, 3),
			Location:           "Concrete Washout Station",
			Latitude:           41.8730,
			Longitude:          -87.6380,
			Division:           "Construction",
			ProjectJobSite:     "Project Beta",
			Description:        "Concrete washwater overflowed containment berm and reached unpaved soil. Estimated 200 gallons.",
			ImmediateActions:   "Flow stopped. Soil scraped and bagged. Environmental coordinator notified.",
			Severity:           "Medium",
			PotentialSeverity:  "Medium",
			Shift:              "Day",
			Weather:            "Overcast",
			Status:             "CAPA In Progress",
			ReporterID:         "dev-field_reporter",
			IsDraft:            false,
			CompletionPercent:  88,
			IsOshaRecordable:   &falseVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
		// 12. Vehicle — Closed
		{
			Type:               "Vehicle",
			Date:               now.AddDate(0, -11, -8),
			Location:           "Highway 30 Offsite Transit",
			Latitude:           41.8900,
			Longitude:          -87.6500,
			Division:           "Operations",
			ProjectJobSite:     "Project Gamma",
			Description:        "Company van rear-ended at a red light during material transport. Driver reported minor neck stiffness.",
			ImmediateActions:   "Police notified. Drug test administered. Vehicle towed for inspection.",
			Severity:           "Low",
			PotentialSeverity:  "Medium",
			Shift:              "Day",
			Weather:            "Fog",
			Status:             "Closed",
			ReporterID:         "dev-field_reporter_2",
			IsDraft:            false,
			CompletionPercent:  100,
			IsOshaRecordable:   &trueVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
		// 13. Injury — Reopened (post-close new info)
		{
			Type:               "Injury",
			Date:               now.AddDate(0, -10, 20),
			Location:           "Track Tamping Operation, Zone A",
			Latitude:           41.8770,
			Longitude:          -87.6310,
			Division:           "Maintenance",
			ProjectJobSite:     "Project Alpha",
			Description:        "Worker reported hearing loss after extended tamping machine operation. No hearing protection worn for approx 4 hrs.",
			ImmediateActions:   "Worker referred to occupational health. Hearing protection policy reviewed.",
			Severity:           "Medium",
			PotentialSeverity:  "High",
			Shift:              "Day",
			Weather:            "Clear",
			Status:             "Reopened",
			ReporterID:         "dev-field_reporter_3",
			IsDraft:            false,
			CompletionPercent:  95,
			IsOshaRecordable:   &trueVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
		// 14. Fire — Reported
		{
			Type:               "Fire",
			Date:               now.AddDate(0, -1, 3),
			Location:           "Generator Room, Site Office",
			Division:           "Operations",
			ProjectJobSite:     "Project Beta",
			Description:        "Electrical fire started in generator wiring harness. Smoke detected by staff. Extinguished before fire department arrived.",
			ImmediateActions:   "Power cut to generator room. Extinguished with CO2. Fire department notified.",
			Severity:           "High",
			PotentialSeverity:  "Critical",
			Shift:              "Evening",
			Weather:            "Clear",
			Status:             "Reported",
			ReporterID:         "dev-field_reporter",
			IsDraft:            false,
			CompletionPercent:  45,
			IsRailroadProperty: false,
		},
		// 15. Near Miss — CAPA Assigned
		{
			Type:               "Near Miss",
			Date:               now.AddDate(0, -4, 12),
			Location:           "Signage Installation Area, Bridge Deck",
			Latitude:           41.8840,
			Longitude:          -87.6180,
			Division:           "Construction",
			ProjectJobSite:     "Project Gamma",
			Description:        "Worker nearly dropped a 20-lb sign panel from 15 ft elevation. Safety line caught the panel.",
			ImmediateActions:   "Work stopped. Drop zone assessed. Rigging procedure reviewed on-site.",
			Severity:           "High",
			PotentialSeverity:  "Critical",
			Shift:              "Day",
			Weather:            "Windy",
			Status:             "CAPA Assigned",
			ReporterID:         "dev-field_reporter_2",
			IsDraft:            false,
			CompletionPercent:  78,
			IsOshaRecordable:   &falseVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
		// 16. Property Damage — Under Investigation, railroad (NS)
		{
			Type:                        "Property Damage",
			Date:                        now.AddDate(0, -5, 18),
			Location:                    "NS Branch Line MP 52, Culvert Work",
			Latitude:                    41.9100,
			Longitude:                   -87.7100,
			Division:                    "Construction",
			ProjectJobSite:              "Project Beta",
			Description:                 "Vibration from compaction equipment cracked an NS-owned signal house foundation.",
			ImmediateActions:            "Compaction stopped. NS track inspector summoned. Area monitored.",
			Severity:                    "Medium",
			PotentialSeverity:           "High",
			Shift:                       "Day",
			Weather:                     "Partly Cloudy",
			Status:                      "Under Investigation",
			ReporterID:                  "dev-field_reporter",
			IsDraft:                     false,
			CompletionPercent:           65,
			IsRailroadProperty:          true,
			RailroadClient:              "NS",
			RailroadNotified:            true,
			RailroadNotificationDate:    timePtr(now.AddDate(0, -5, 18).Add(90 * time.Minute)),
			RailroadNotificationMethod:  "Email",
			RailroadNotificationOverdue: false,
		},
		// 17. Utility Strike — Closed
		{
			Type:               "Utility Strike",
			Date:               now.AddDate(0, -11, -2),
			Location:           "East Corridor, Trench Segment 4",
			Latitude:           41.8750,
			Longitude:          -87.6260,
			Division:           "Operations",
			ProjectJobSite:     "Project Alpha",
			Description:        "Drill bit struck an unmarked water main at 6 ft. No injuries. Minor service disruption to adjacent building.",
			ImmediateActions:   "Drill stopped. Water authority notified. Area cordoned. Service restored in 4 hours.",
			Severity:           "Low",
			PotentialSeverity:  "Medium",
			Shift:              "Day",
			Weather:            "Clear",
			Status:             "Closed",
			ReporterID:         "dev-field_reporter_3",
			IsDraft:            false,
			CompletionPercent:  100,
			IsOshaRecordable:   &falseVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
		// 18. Injury — Reported (recent), OSHA recordable
		{
			Type:               "Injury",
			Date:               now.AddDate(0, 0, -5),
			Location:           "Material Receiving Dock",
			Latitude:           41.8790,
			Longitude:          -87.6300,
			Division:           "Operations",
			ProjectJobSite:     "Project Alpha",
			Description:        "Warehouse worker strained lower back lifting a 75-lb box without mechanical assist.",
			ImmediateActions:   "Worker given light duty. Incident reported to safety coordinator. Ergonomic assessment ordered.",
			Severity:           "Medium",
			PotentialSeverity:  "High",
			Shift:              "Day",
			Weather:            "Indoor",
			Status:             "Reported",
			ReporterID:         "dev-field_reporter",
			IsDraft:            false,
			CompletionPercent:  50,
			IsOshaRecordable:   &trueVal,
			IsDart:             &falseVal,
			IsRailroadProperty: false,
		},
	}

	for _, inc := range incidents {
		if err := db.Create(inc).Error; err != nil {
			log.Printf("Seed: failed to create incident: %v", err)
		}
	}

	// -------------------------------------------------------------------------
	// Injured Persons — linked to injury incidents (IDs 1, 8, 13)
	// Medical fields encrypted.
	// -------------------------------------------------------------------------
	injuredPersons := []models.InjuredPerson{
		// Incident 1 (laceration)
		{
			IncidentID:         incidents[0].ID,
			Name:               "Marcus Webb",
			JobTitle:           "Equipment Operator",
			Division:           "Construction",
			InjuryType:         mustEncrypt("Laceration"),
			BodyPart:           mustEncrypt("Hand"),
			BodyPartSide:       "Left",
			TreatmentType:      mustEncrypt("Medical Treatment"),
			ReturnToWorkStatus: mustEncrypt("Returned Full Duty"),
		},
		// Incident 8 (scaffold fall) — 2 injured persons
		{
			IncidentID:         incidents[7].ID,
			Name:               "Diana Reyes",
			JobTitle:           "Scaffold Worker",
			Division:           "Maintenance",
			InjuryType:         mustEncrypt("Fracture"),
			BodyPart:           mustEncrypt("Wrist"),
			BodyPartSide:       "Right",
			TreatmentType:      mustEncrypt("Hospitalization"),
			ReturnToWorkStatus: mustEncrypt("On Medical Leave"),
		},
		{
			IncidentID:         incidents[7].ID,
			Name:               "Trevor Holt",
			JobTitle:           "Scaffold Worker",
			Division:           "Maintenance",
			InjuryType:         mustEncrypt("Sprain/Strain"),
			BodyPart:           mustEncrypt("Ankle"),
			BodyPartSide:       "Left",
			TreatmentType:      mustEncrypt("First Aid"),
			ReturnToWorkStatus: mustEncrypt("Returned Light Duty"),
		},
		// Incident 13 (hearing loss)
		{
			IncidentID:         incidents[12].ID,
			Name:               "Geraldine Park",
			JobTitle:           "Track Maintenance Worker",
			Division:           "Maintenance",
			InjuryType:         mustEncrypt("Noise-Induced Hearing Loss"),
			BodyPart:           mustEncrypt("Ear"),
			BodyPartSide:       "Both",
			TreatmentType:      mustEncrypt("Medical Treatment"),
			ReturnToWorkStatus: mustEncrypt("Returned Modified Duty"),
		},
	}
	db.Create(&injuredPersons)

	// -------------------------------------------------------------------------
	// Investigations (7) — linked to incidents 1, 2, 3, 5, 7, 8, 16
	// -------------------------------------------------------------------------
	now14 := now.AddDate(0, 0, -14)
	overduePast := now.AddDate(0, -1, -10) // already passed — overdue

	investigations := []*models.Investigation{
		// Inv 1 — for incident 1 (Injury/Closed) — Approved
		{
			IncidentID:             incidents[0].ID,
			LeadInvestigatorID:     "dev-safety_coordinator",
			TeamMembers:            `["dev-safety_coordinator_2","dev-pm"]`,
			TargetCompletionDate:   now.AddDate(0, -10, 20),
			ActualCompletionDate:   timePtr(now.AddDate(0, -10, 25)),
			Status:                 "Approved",
			AssignedBy:             "dev-safety_manager",
			ReviewedBy:             "dev-safety_manager",
			ReviewComments:         "Thorough investigation. Root cause clearly identified. CAPAs are appropriate.",
			ReviewDate:             timePtr(now.AddDate(0, -10, 26)),
			IsOverdue:              false,
			OverdueEscalationLevel: 0,
		},
		// Inv 2 — for incident 2 (Near Miss) — In Progress
		{
			IncidentID:             incidents[1].ID,
			LeadInvestigatorID:     "dev-safety_coordinator",
			TeamMembers:            `["dev-safety_coordinator_2"]`,
			TargetCompletionDate:   now.AddDate(0, -7, 11),
			Status:                 "In Progress",
			AssignedBy:             "dev-safety_manager",
			IsOverdue:              true,
			OverdueEscalationLevel: 3,
		},
		// Inv 3 — for incident 3 (Property Damage/Railroad) — Approved
		{
			IncidentID:             incidents[2].ID,
			LeadInvestigatorID:     "dev-safety_coordinator_2",
			TeamMembers:            `["dev-safety_coordinator"]`,
			TargetCompletionDate:   now.AddDate(0, -5, 24),
			ActualCompletionDate:   timePtr(now.AddDate(0, -5, 22)),
			Status:                 "Approved",
			AssignedBy:             "dev-safety_manager_2",
			ReviewedBy:             "dev-safety_manager_2",
			ReviewComments:         "Good documentation. Railroad notification timeline confirmed.",
			ReviewDate:             timePtr(now.AddDate(0, -5, 23)),
			IsOverdue:              false,
			OverdueEscalationLevel: 0,
		},
		// Inv 4 — for incident 5 (Vehicle) — Approved (Investigation Complete)
		{
			IncidentID:             incidents[4].ID,
			LeadInvestigatorID:     "dev-safety_coordinator",
			TeamMembers:            `["dev-pm_2"]`,
			TargetCompletionDate:   now.AddDate(0, -6, 9),
			ActualCompletionDate:   timePtr(now.AddDate(0, -6, 8)),
			Status:                 "Approved",
			AssignedBy:             "dev-safety_manager",
			ReviewedBy:             "dev-safety_manager",
			ReviewComments:         "Investigation complete. Recommended defensive driving refresher.",
			ReviewDate:             timePtr(now.AddDate(0, -6, 9)),
			IsOverdue:              false,
			OverdueEscalationLevel: 0,
		},
		// Inv 5 — for incident 7 (Utility Strike/Critical) — Under Review
		{
			IncidentID:             incidents[6].ID,
			LeadInvestigatorID:     "dev-safety_coordinator_2",
			TeamMembers:            `["dev-safety_coordinator","dev-safety_manager_2"]`,
			TargetCompletionDate:   now.AddDate(0, -2, 20),
			Status:                 "Under Review",
			AssignedBy:             "dev-safety_manager_2",
			IsOverdue:              false,
			OverdueEscalationLevel: 0,
		},
		// Inv 6 — for incident 8 (Scaffold Fall) — In Progress, overdue
		{
			IncidentID:             incidents[7].ID,
			LeadInvestigatorID:     "dev-safety_coordinator",
			TeamMembers:            `["dev-safety_coordinator_2","dev-pm"]`,
			TargetCompletionDate:   overduePast,
			Status:                 "In Progress",
			AssignedBy:             "dev-safety_manager",
			IsOverdue:              true,
			OverdueEscalationLevel: 2,
		},
		// Inv 7 — for incident 16 (Property Damage/NS Railroad) — Assigned
		{
			IncidentID:             incidents[15].ID,
			LeadInvestigatorID:     "dev-safety_coordinator_2",
			TeamMembers:            `[]`,
			TargetCompletionDate:   now14,
			Status:                 "Assigned",
			AssignedBy:             "dev-safety_manager_2",
			IsOverdue:              false,
			OverdueEscalationLevel: 0,
		},
	}

	for _, inv := range investigations {
		if err := db.Create(inv).Error; err != nil {
			log.Printf("Seed: failed to create investigation: %v", err)
		}
	}

	// -------------------------------------------------------------------------
	// Five Whys — 3-5 per investigation
	// -------------------------------------------------------------------------
	type whyEntry struct {
		invIdx    int
		level     int
		question  string
		answer    string
		evidence  string
		sortOrder int
	}
	whys := []whyEntry{
		// Inv 1 (laceration)
		{0, 1, "Why did the worker sustain a laceration?", "The cutting tool slipped during use.", "Tool inspection report; photo evidence.", 1},
		{0, 2, "Why did the cutting tool slip?", "The blade guard was removed prior to the cut.", "Witness statement; blade guard found 3 ft from workstation.", 2},
		{0, 3, "Why was the blade guard removed?", "Worker reported the guard made precise cuts difficult.", "Interview notes from supervisor.", 3},
		{0, 4, "Why was this accepted practice allowed?", "No formal PPE/tool guard verification step in the work procedure.", "Procedure document review.", 4},
		{0, 5, "Why was there no verification step?", "Last procedure revision omitted guard checks.", "Procedure revision history log.", 5},

		// Inv 2 (crane near miss)
		{1, 1, "Why was the load nearly struck?", "The crane swing arc overlapped the pedestrian walkway.", "Site layout drawing.", 1},
		{1, 2, "Why did the swing arc overlap the walkway?", "The lift plan was not reviewed for the updated site layout.", "Lift plan vs. site layout comparison.", 2},
		{1, 3, "Why was the lift plan not updated?", "Site layout changed 2 days prior but crane operator was not notified.", "Communication log; site change notice.", 3},
		{1, 4, "Why was the operator not notified?", "No formal change communication protocol for active lift operations.", "Safety communication SOP review.", 4},

		// Inv 3 (BNSF property damage)
		{2, 1, "Why was the conduit struck?", "Excavator bucket depth exceeded design plan.", "Survey staking records.", 1},
		{2, 2, "Why did the excavator exceed planned depth?", "Operator did not have updated utility locate flags in the cab.", "Operator interview; locate flag records.", 2},
		{2, 3, "Why were locate flags not in the cab?", "Ground disturbance permit did not include fiber-optic utilities.", "Permit documentation.", 3},
		{2, 4, "Why were fiber-optic utilities omitted?", "One-call response was incomplete for this segment.", "811 response records.", 4},
		{2, 5, "Why was the one-call response incomplete?", "The request window expired before all utilities responded.", "One-call ticket history.", 5},

		// Inv 4 (vehicle)
		{3, 1, "Why did the van collide with the trailer?", "Driver reversed without using a spotter.", "Security camera footage.", 1},
		{3, 2, "Why was no spotter used?", "Driver believed the area was clear based on a visual check only.", "Driver interview.", 2},
		{3, 3, "Why did the driver rely only on visual check?", "Backing procedure does not require a spotter for loads under 10 ft.", "Driving procedure document.", 3},

		// Inv 5 (utility strike gas line)
		{4, 1, "Why was the gas line struck?", "The line was unmarked on site drawings and locate tickets.", "As-built drawings; locate response.", 1},
		{4, 2, "Why was the gas line not on as-built drawings?", "Line installed after last survey update in 2019.", "Survey date records.", 2},
		{4, 3, "Why were survey drawings not current?", "No requirement to update as-builts before each ground disturbance permit.", "Permit SOP review.", 3},
		{4, 4, "Why was potholing not performed?", "Potholing was optional in the procedure for depths under 5 ft.", "Ground disturbance procedure v4.", 4},

		// Inv 6 (scaffold fall)
		{5, 1, "Why did the worker fall?", "The scaffold platform lacked toe boards and had a gap in the guardrail.", "Site inspection photos.", 1},
		{5, 2, "Why were toe boards and guardrails missing?", "Scaffold was erected by a sub-contractor who used their own standard.", "Sub-contractor scaffold spec.", 2},
		{5, 3, "Why was the sub-contractor standard accepted?", "Pre-work safety inspection did not verify scaffold compliance with OSHA 1926.451.", "Pre-work inspection checklist.", 3},
		{5, 4, "Why was compliance not verified?", "Inspector checklist did not include guardrail continuity check.", "Checklist review.", 4},
		{5, 5, "Why was the checklist incomplete?", "Checklist last updated 4 years ago before toe-board rule revision.", "Checklist revision log.", 5},

		// Inv 7 (NS signal house)
		{6, 1, "Why did the vibration crack the foundation?", "Compaction equipment operated within 10 ft of the signal house.", "As-built drawings; vibration log.", 1},
		{6, 2, "Why was equipment operated so close?", "Exclusion zone was not defined in the work plan.", "Work plan document.", 2},
		{6, 3, "Why was no exclusion zone defined?", "Railroad protection plan did not identify the signal house as a sensitive structure.", "Railroad protection plan.", 3},
	}

	for _, w := range whys {
		fw := models.FiveWhy{
			InvestigationID: investigations[w.invIdx].ID,
			Level:           w.level,
			Question:        w.question,
			Answer:          w.answer,
			Evidence:        w.evidence,
			SortOrder:       w.sortOrder,
		}
		db.Create(&fw)
	}

	// -------------------------------------------------------------------------
	// Contributing Factors — 1 primary + 1-2 additional per investigation
	// -------------------------------------------------------------------------
	type factorEntry struct {
		invIdx      int
		factorType  string
		description string
		isPrimary   bool
	}
	factors := []factorEntry{
		// Inv 1
		{0, "Procedural", "Blade guard removal not covered in task procedure; no verification step.", true},
		{0, "People", "Worker removed guard without authorization or risk assessment.", false},
		// Inv 2
		{1, "Management/Organizational", "No formal change communication protocol for active crane operations.", true},
		{1, "Procedural", "Lift plan review cycle did not account for site changes.", false},
		// Inv 3
		{2, "Procedural", "Ground disturbance permit process lacked comprehensive utility locate verification.", true},
		{2, "Equipment", "No in-cab locate documentation available to operator.", false},
		// Inv 4
		{3, "Procedural", "Backing procedure allowed single-person reversal without spotter.", true},
		// Inv 5
		{4, "Management/Organizational", "No policy requiring current as-built surveys before ground disturbance.", true},
		{4, "Procedural", "Potholing waiver for depths under 5 ft created unacceptable risk.", false},
		{4, "Environmental", "Aged utility infrastructure not reflected in available records.", false},
		// Inv 6
		{5, "Management/Organizational", "Sub-contractor scaffold standards not verified against OSHA 1926.451.", true},
		{5, "Procedural", "Pre-work inspection checklist was out of date.", false},
		// Inv 7
		{6, "Procedural", "Railroad protection plan did not classify signal house as a sensitive structure.", true},
		{6, "Equipment", "Exclusion zone signage not installed around signal house prior to compaction work.", false},
	}

	for _, f := range factors {
		cf := models.ContributingFactor{
			InvestigationID:   investigations[f.invIdx].ID,
			FactorType:        f.factorType,
			FactorDescription: f.description,
			IsPrimary:         f.isPrimary,
		}
		db.Create(&cf)
	}

	// -------------------------------------------------------------------------
	// Witness Statements — on investigations 1, 3, 6
	// -------------------------------------------------------------------------
	witnesses := []models.WitnessStatement{
		// Inv 1
		{
			InvestigationID: investigations[0].ID,
			WitnessName:     "Larry Gomez",
			WitnessTitle:    "General Foreman",
			WitnessEmployer: "Herzog Technologies Inc.",
			WitnessPhone:    "312-555-0101",
			StatementText:   "I was 20 ft away when the incident occurred. I heard Marcus shout and saw him holding his hand. The blade guard was on the floor. I applied first aid immediately.",
			CollectionDate:  now.AddDate(0, -11, 6),
			CollectorName:   "J. Martinez",
		},
		{
			InvestigationID: investigations[0].ID,
			WitnessName:     "Priya Nair",
			WitnessTitle:    "Safety Technician",
			WitnessEmployer: "Herzog Technologies Inc.",
			WitnessPhone:    "312-555-0102",
			StatementText:   "I arrived on scene within 3 minutes. The blade guard was visibly removed. Worker stated he removed it because it was slowing him down.",
			CollectionDate:  now.AddDate(0, -11, 6),
			CollectorName:   "J. Martinez",
		},
		// Inv 3
		{
			InvestigationID: investigations[2].ID,
			WitnessName:     "Ben Hartley",
			WitnessTitle:    "BNSF Track Supervisor",
			WitnessEmployer: "BNSF Railway",
			WitnessPhone:    "402-555-0201",
			StatementText:   "The fiber-optic conduit depth was approximately 2.5 ft. There were no locate flags in that 50-ft section. We discovered the strike when our signal system alerted.",
			CollectionDate:  now.AddDate(0, -6, 12),
			CollectorName:   "S. Patel",
		},
		// Inv 6
		{
			InvestigationID: investigations[5].ID,
			WitnessName:     "Rosa Delgado",
			WitnessTitle:    "Safety Observer",
			WitnessEmployer: "Herzog Technologies Inc.",
			WitnessPhone:    "312-555-0301",
			StatementText:   "I observed Diana fall from the third-level platform. The guardrail had a gap of approximately 3 feet. Trevor was also on the platform and twisted his ankle trying to reach her.",
			CollectionDate:  now.AddDate(0, -5, 0),
			CollectorName:   "R. Chen",
		},
		{
			InvestigationID: investigations[5].ID,
			WitnessName:     "Sub-Contractor Foreman (name withheld)",
			WitnessTitle:    "Scaffold Foreman",
			WitnessEmployer: "Apex Scaffold LLC",
			WitnessPhone:    "773-555-0302",
			StatementText:   "Our scaffold standard follows SSFI guidelines. We were not provided Herzog's specific guardrail continuity requirement before erection.",
			CollectionDate:  now.AddDate(0, -4, 28),
			CollectorName:   "R. Chen",
		},
	}
	db.Create(&witnesses)

	// -------------------------------------------------------------------------
	// CAPAs (14 total)
	// -------------------------------------------------------------------------
	comp1 := now.AddDate(0, -10, 15)
	comp2 := now.AddDate(0, -9, 10)
	comp3 := now.AddDate(0, -5, 5)
	comp4 := now.AddDate(0, -4, 20)
	comp5 := now.AddDate(0, -6, 1)

	vDue1 := comp1.AddDate(0, 1, 0) // High: 60d post-completion
	vDue3 := comp3.AddDate(0, 3, 0) // Medium: 90d
	vDue5 := comp5.AddDate(0, 1, 0) // Critical: 30d

	capas := []*models.CAPA{
		// CAPA 1 — Inv 1 / Incident 1 — Verified Effective (Critical)
		{
			InvestigationID:     investigations[0].ID,
			IncidentID:          incidents[0].ID,
			Type:                "Corrective",
			Category:            "Procedure Change",
			Description:         "Revise cutting tool procedure to require blade guard verification before and after use. Supervisor sign-off required.",
			AssignedToUserID:    "dev-safety_coordinator",
			AssignedByUserID:    "dev-safety_manager",
			DueDate:             now.AddDate(0, -10, 12),
			Priority:            "Critical",
			VerificationMethod:  "Procedure document review and field observation at next cutting operation.",
			VerificationDueDate: &vDue5,
			Status:              "Verified Effective",
			CompletionNotes:     "New procedure published and distributed. All operators briefed.",
			CompletionEvidence:  "Revised Procedure SOP-CUT-007 v2.0",
			CompletionDate:      &comp1,
			VerifiedByUserID:    "dev-safety_manager",
			VerificationDate:    timePtr(vDue5.AddDate(0, 0, -5)),
			VerificationNotes:   "Field observation confirmed blade guard in place for all cutting operations. SOP updated in system.",
			IsOverdue:           false,
		},
		// CAPA 2 — Inv 1 / Incident 1 — Verified Effective (High)
		{
			InvestigationID:     investigations[0].ID,
			IncidentID:          incidents[0].ID,
			Type:                "Preventive",
			Category:            "Training",
			Description:         "Mandatory refresher training on tool safety and PPE requirements for all equipment operators.",
			AssignedToUserID:    "dev-safety_coordinator_2",
			AssignedByUserID:    "dev-safety_manager",
			DueDate:             now.AddDate(0, -10, 7),
			Priority:            "High",
			VerificationMethod:  "Training attendance records and post-training assessment results.",
			VerificationDueDate: &vDue1,
			Status:              "Verified Effective",
			CompletionNotes:     "22 of 22 operators completed training. Average assessment score: 94%.",
			CompletionEvidence:  "Training attendance sheet; assessment records",
			CompletionDate:      &comp2,
			VerifiedByUserID:    "dev-safety_manager",
			VerificationDate:    timePtr(vDue1.AddDate(0, 0, -10)),
			VerificationNotes:   "No recurrence of unguarded tool use in subsequent 60-day period.",
			IsOverdue:           false,
		},
		// CAPA 3 — Inv 2 / Incident 2 — In Progress (High)
		{
			InvestigationID:  investigations[1].ID,
			IncidentID:       incidents[1].ID,
			Type:             "Corrective",
			Category:         "Procedure Change",
			Description:      "Implement formal site layout change notification protocol requiring all active permit holders to acknowledge changes within 2 hours.",
			AssignedToUserID: "dev-pm",
			AssignedByUserID: "dev-safety_manager",
			DueDate:          now.AddDate(0, -7, 0),
			Priority:         "High",
			Status:           "In Progress",
			IsOverdue:        true,
		},
		// CAPA 4 — Inv 2 / Incident 2 — Open (Medium)
		{
			InvestigationID:  investigations[1].ID,
			IncidentID:       incidents[1].ID,
			Type:             "Preventive",
			Category:         "Engineering Control",
			Description:      "Install physical barricades separating crane swing zones from pedestrian routes for all lifts over 500 lbs.",
			AssignedToUserID: "dev-safety_coordinator",
			AssignedByUserID: "dev-safety_manager",
			DueDate:          now.AddDate(0, 0, 14),
			Priority:         "Medium",
			Status:           "Open",
			IsOverdue:        false,
		},
		// CAPA 5 — Inv 3 / Incident 3 — Verified Effective (Critical)
		{
			InvestigationID:     investigations[2].ID,
			IncidentID:          incidents[2].ID,
			Type:                "Corrective",
			Category:            "Procedure Change",
			Description:         "Revise ground disturbance permit to require 100% utility locate verification including fiber-optic and low-voltage systems before permit issuance.",
			AssignedToUserID:    "dev-pm_2",
			AssignedByUserID:    "dev-safety_manager_2",
			DueDate:             now.AddDate(0, -5, 14),
			Priority:            "Critical",
			VerificationMethod:  "Permit audit — 10 consecutive permits reviewed for locate completeness.",
			VerificationDueDate: &vDue5,
			Status:              "Verified Effective",
			CompletionNotes:     "Permit template updated. Locate verification checklist embedded. All PMs briefed.",
			CompletionEvidence:  "Updated permit template v3.1; PM acknowledgement log",
			CompletionDate:      &comp3,
			VerifiedByUserID:    "dev-safety_manager_2",
			VerificationDate:    timePtr(vDue3),
			VerificationNotes:   "Audit of 10 permits: all included complete locate verification. No recurrence.",
			IsOverdue:           false,
		},
		// CAPA 6 — Inv 4 / Incident 5 — Verified Effective (Medium)
		{
			InvestigationID:     investigations[3].ID,
			IncidentID:          incidents[4].ID,
			Type:                "Corrective",
			Category:            "Procedure Change",
			Description:         "Update vehicle backing procedure to require a spotter for all reversing maneuvers on site regardless of load or distance.",
			AssignedToUserID:    "dev-safety_coordinator",
			AssignedByUserID:    "dev-safety_manager",
			DueDate:             now.AddDate(0, -6, 2),
			Priority:            "Medium",
			VerificationMethod:  "Spot audits of vehicle operations over 30-day period.",
			VerificationDueDate: &vDue3,
			Status:              "Verified Effective",
			CompletionNotes:     "Backing procedure updated. All drivers acknowledged new requirement.",
			CompletionEvidence:  "Updated driving SOP; driver acknowledgement forms",
			CompletionDate:      &comp4,
			VerifiedByUserID:    "dev-safety_manager",
			VerificationDate:    timePtr(vDue3.AddDate(0, 0, -3)),
			VerificationNotes:   "Spot audits confirmed spotter use in all 12 observed reversals.",
			IsOverdue:           false,
		},
		// CAPA 7 — Inv 5 / Incident 7 — Open (Critical)
		{
			InvestigationID:  investigations[4].ID,
			IncidentID:       incidents[6].ID,
			Type:             "Corrective",
			Category:         "Procedure Change",
			Description:      "Mandate potholing to confirm utility depth regardless of design depth before any ground disturbance within 5 ft of known utilities.",
			AssignedToUserID: "dev-pm",
			AssignedByUserID: "dev-safety_manager_2",
			DueDate:          now.AddDate(0, -1, 0),
			Priority:         "Critical",
			Status:           "Open",
			IsOverdue:        true,
		},
		// CAPA 8 — Inv 5 / Incident 7 — Open (High)
		{
			InvestigationID:  investigations[4].ID,
			IncidentID:       incidents[6].ID,
			Type:             "Preventive",
			Category:         "Policy Change",
			Description:      "Require as-built drawing updates every 2 years and before any ground disturbance permit for projects over 6 months in duration.",
			AssignedToUserID: "dev-division_manager",
			AssignedByUserID: "dev-safety_manager_2",
			DueDate:          now.AddDate(0, 0, 30),
			Priority:         "High",
			Status:           "Open",
			IsOverdue:        false,
		},
		// CAPA 9 — Inv 6 / Incident 8 — Completed (Verification Pending, Critical)
		{
			InvestigationID:     investigations[5].ID,
			IncidentID:          incidents[7].ID,
			Type:                "Corrective",
			Category:            "Procedure Change",
			Description:         "Revise scaffold inspection checklist to require OSHA 1926.451 guardrail continuity check and toe-board verification. Sub-contractor compliance must be verified by Herzog safety rep before use.",
			AssignedToUserID:    "dev-safety_coordinator_2",
			AssignedByUserID:    "dev-safety_manager",
			DueDate:             now.AddDate(0, -4, 0),
			Priority:            "Critical",
			VerificationMethod:  "Next 5 scaffold erections inspected by Safety Manager against updated checklist.",
			VerificationDueDate: timePtr(now.AddDate(0, -4, 0).Add(30 * 24 * time.Hour)),
			Status:              "Verification Pending",
			CompletionNotes:     "New checklist issued. Sub-contractor briefed. First inspection conducted.",
			CompletionEvidence:  "Revised inspection checklist v2; sub-contractor briefing record",
			CompletionDate:      &comp5,
			IsOverdue:           false,
		},
		// CAPA 10 — Inv 6 / Incident 8 — In Progress (High)
		{
			InvestigationID:  investigations[5].ID,
			IncidentID:       incidents[7].ID,
			Type:             "Preventive",
			Category:         "Training",
			Description:      "Require all sub-contractors to submit scaffold erection plan for safety review 24 hours before erection commences.",
			AssignedToUserID: "dev-pm",
			AssignedByUserID: "dev-safety_manager",
			DueDate:          now.AddDate(0, -2, 0),
			Priority:         "High",
			Status:           "In Progress",
			IsOverdue:        true,
		},
		// CAPA 11 — Inv 7 / Incident 16 — Open (Medium)
		{
			InvestigationID:  investigations[6].ID,
			IncidentID:       incidents[15].ID,
			Type:             "Corrective",
			Category:         "Engineering Control",
			Description:      "Install vibration monitoring at all railroad-owned structures within 50 ft of compaction operations. Halt work if threshold exceeded.",
			AssignedToUserID: "dev-safety_coordinator",
			AssignedByUserID: "dev-safety_manager_2",
			DueDate:          now.AddDate(0, 0, 21),
			Priority:         "Medium",
			Status:           "Open",
			IsOverdue:        false,
		},
		// CAPA 12 — no investigation — direct from incident 11 (Environmental) — Verified Ineffective
		{
			InvestigationID:     0,
			IncidentID:          incidents[10].ID,
			Type:                "Corrective",
			Category:            "Engineering Control",
			Description:         "Install secondary berm around concrete washout station to contain 125% of typical batch volume.",
			AssignedToUserID:    "dev-safety_coordinator_2",
			AssignedByUserID:    "dev-safety_manager",
			DueDate:             now.AddDate(0, -8, 5),
			Priority:            "Medium",
			VerificationMethod:  "Visual inspection after next washout event.",
			VerificationDueDate: timePtr(now.AddDate(0, -8, 5).Add(90 * 24 * time.Hour)),
			Status:              "Verified Ineffective",
			CompletionNotes:     "Berm raised by 6 inches using soil. No concrete liner added.",
			CompletionEvidence:  "Before/after photos of berm",
			CompletionDate:      timePtr(now.AddDate(0, -8, 2)),
			VerifiedByUserID:    "dev-safety_manager",
			VerificationDate:    timePtr(now.AddDate(0, -7, 5)),
			VerificationNotes:   "Berm failed during next event — water still overflowed at northeast corner. Concrete liner required.",
			IsOverdue:           false,
		},
		// CAPA 13 — follow-up to CAPA 12 — Open (High)
		{
			InvestigationID:  0,
			IncidentID:       incidents[10].ID,
			Type:             "Corrective",
			Category:         "Engineering Control",
			Description:      "Replace soil berm with poured concrete containment wall minimum 18 inches tall around washout station.",
			AssignedToUserID: "dev-pm_2",
			AssignedByUserID: "dev-safety_manager",
			DueDate:          now.AddDate(0, 0, 45),
			Priority:         "High",
			Status:           "Open",
			IsOverdue:        false,
		},
		// CAPA 14 — Incident 15 (Near Miss/Sign Drop) — In Progress (High)
		{
			InvestigationID:  0,
			IncidentID:       incidents[14].ID,
			Type:             "Corrective",
			Category:         "PPE",
			Description:      "Require tethering systems for all tools and materials handled above 10 ft elevation. Install drop-zone barriers.",
			AssignedToUserID: "dev-safety_coordinator",
			AssignedByUserID: "dev-safety_manager_2",
			DueDate:          now.AddDate(0, -3, 12),
			Priority:         "High",
			Status:           "In Progress",
			IsOverdue:        true,
		},
	}

	for _, c := range capas {
		if c.InvestigationID == 0 {
			c.InvestigationID = 0 // stays zero (nullable-ish — the field allows it)
		}
		if err := db.Create(c).Error; err != nil {
			log.Printf("Seed: failed to create CAPA: %v", err)
		}
	}

	// -------------------------------------------------------------------------
	// Incident Links — 3 linked pairs for recurrence demo
	// -------------------------------------------------------------------------
	incidentLinks := []models.IncidentLink{
		// Incidents 1 & 8 — both injuries, same division
		{
			IncidentID1:    incidents[0].ID,
			IncidentID2:    incidents[7].ID,
			SimilarityType: "Same Type",
			Notes:          "Both are injury incidents in the Maintenance/Construction divisions involving inadequate PPE or equipment safeguards.",
			LinkedByUserID: "dev-safety_coordinator",
		},
		// Incidents 3 & 16 — both railroad property damage
		{
			IncidentID1:    incidents[2].ID,
			IncidentID2:    incidents[15].ID,
			SimilarityType: "Same Location",
			Notes:          "Both occurred on active railroad right-of-way. Common thread: ground disturbance near railroad infrastructure.",
			LinkedByUserID: "dev-safety_coordinator_2",
		},
		// Incidents 7 & 17 — both utility strikes
		{
			IncidentID1:    incidents[6].ID,
			IncidentID2:    incidents[16].ID,
			SimilarityType: "Same Root Cause",
			Notes:          "Both utility strikes share the root cause of inadequate ground disturbance permit and locate verification process.",
			LinkedByUserID: "dev-safety_coordinator",
		},
	}
	db.Create(&incidentLinks)

	// -------------------------------------------------------------------------
	// Notifications — a few unread for demo
	// -------------------------------------------------------------------------
	notifications := []models.Notification{
		{
			UserID:          "dev-safety_manager",
			Title:           "Investigation Overdue: Near Miss (Crane)",
			Message:         "Investigation INV-002 is 30+ days overdue. Immediate follow-up required.",
			Type:            "overdue_investigation",
			EntityType:      "investigation",
			EntityID:        investigations[1].ID,
			EscalationLevel: 3,
			IsRead:          false,
		},
		{
			UserID:          "dev-safety_manager",
			Title:           "Investigation Overdue: Scaffold Fall",
			Message:         "Investigation INV-006 is overdue. Worker injury investigation requires priority attention.",
			Type:            "overdue_investigation",
			EntityType:      "investigation",
			EntityID:        investigations[5].ID,
			EscalationLevel: 2,
			IsRead:          false,
		},
		{
			UserID:          "dev-pm",
			Title:           "CAPA Overdue: Site Layout Protocol",
			Message:         "CAPA for incident 'Near Miss – Crane' is past due. Please update status or request extension.",
			Type:            "overdue_capa",
			EntityType:      "capa",
			EntityID:        capas[2].ID,
			EscalationLevel: 1,
			IsRead:          false,
		},
		{
			UserID:          "dev-safety_manager_2",
			Title:           "CAPA Critical Overdue: Utility Strike Gas Line",
			Message:         "Critical CAPA for utility strike incident is overdue. Immediate corrective action needed.",
			Type:            "overdue_capa",
			EntityType:      "capa",
			EntityID:        capas[6].ID,
			EscalationLevel: 2,
			IsRead:          false,
		},
		{
			UserID:          "dev-safety_manager",
			Title:           "Investigation Ready for Review: Utility Strike",
			Message:         "Investigation INV-005 has been submitted for review by the lead investigator.",
			Type:            "review_request",
			EntityType:      "investigation",
			EntityID:        investigations[4].ID,
			EscalationLevel: 0,
			IsRead:          true,
		},
		{
			UserID:          "dev-safety_manager",
			Title:           "Railroad Notification Overdue: UP Utility Strike",
			Message:         "Incident on UP railroad property has not been reported to UP within the required timeframe.",
			Type:            "railroad_notification",
			EntityType:      "incident",
			EntityID:        incidents[6].ID,
			EscalationLevel: 1,
			IsRead:          false,
		},
	}
	db.Create(&notifications)

	// -------------------------------------------------------------------------
	// Audit Log Entries — representative history for audit log viewer demo
	// -------------------------------------------------------------------------
	auditLogs := []models.AuditLog{
		// Incident 1 lifecycle
		{Timestamp: now.AddDate(0, -11, 5), UserID: "dev-field_reporter", UserRole: "field_reporter", Action: "create", EntityType: "incident", EntityID: incidents[0].ID, Before: "", After: `{"type":"Injury","status":"Reported","division":"Construction"}`, Notes: "Incident reported"},
		{Timestamp: now.AddDate(0, -11, 6), UserID: "dev-safety_manager", UserRole: "safety_manager", Action: "assign", EntityType: "investigation", EntityID: investigations[0].ID, Before: "", After: `{"status":"Assigned","leadInvestigatorId":"dev-safety_coordinator"}`, Notes: "Investigation assigned"},
		{Timestamp: now.AddDate(0, -10, 25), UserID: "dev-safety_coordinator", UserRole: "safety_coordinator", Action: "status_change", EntityType: "investigation", EntityID: investigations[0].ID, Before: `{"status":"In Progress"}`, After: `{"status":"Under Review"}`, Notes: "Submitted for review"},
		{Timestamp: now.AddDate(0, -10, 26), UserID: "dev-safety_manager", UserRole: "safety_manager", Action: "approve", EntityType: "investigation", EntityID: investigations[0].ID, Before: `{"status":"Under Review"}`, After: `{"status":"Approved"}`, Notes: "Thorough investigation. Root cause clearly identified."},
		{Timestamp: now.AddDate(0, -10, 26), UserID: "dev-safety_manager", UserRole: "safety_manager", Action: "create", EntityType: "capa", EntityID: capas[0].ID, Before: "", After: `{"type":"Corrective","priority":"Critical","status":"Open"}`, Notes: "CAPA created from investigation"},
		{Timestamp: now.AddDate(0, -10, 15), UserID: "dev-safety_coordinator", UserRole: "safety_coordinator", Action: "status_change", EntityType: "capa", EntityID: capas[0].ID, Before: `{"status":"In Progress"}`, After: `{"status":"Completed"}`, Notes: "Corrective procedure published"},
		{Timestamp: now.AddDate(0, -9, 5), UserID: "dev-safety_manager", UserRole: "safety_manager", Action: "verify", EntityType: "capa", EntityID: capas[0].ID, Before: `{"status":"Verification Pending"}`, After: `{"status":"Verified Effective"}`, Notes: "Field observation confirmed compliance"},
		{Timestamp: now.AddDate(0, -8, 20), UserID: "dev-safety_manager", UserRole: "safety_manager", Action: "status_change", EntityType: "incident", EntityID: incidents[0].ID, Before: `{"status":"CAPA In Progress"}`, After: `{"status":"Closed"}`, Notes: "All CAPAs verified effective. Incident closed."},

		// Incident 7 (utility strike) — partial lifecycle
		{Timestamp: now.AddDate(0, -3, 8), UserID: "dev-field_reporter_3", UserRole: "field_reporter", Action: "create", EntityType: "incident", EntityID: incidents[6].ID, Before: "", After: `{"type":"Utility Strike","status":"Reported","division":"Construction","isRailroadProperty":true}`, Notes: "Critical utility strike reported"},
		{Timestamp: now.AddDate(0, -3, 8), UserID: "dev-safety_manager_2", UserRole: "safety_manager", Action: "assign", EntityType: "investigation", EntityID: investigations[4].ID, Before: "", After: `{"status":"Assigned","leadInvestigatorId":"dev-safety_coordinator_2"}`, Notes: "Urgent investigation assigned"},
		{Timestamp: now.AddDate(0, -2, 22), UserID: "dev-safety_coordinator_2", UserRole: "safety_coordinator", Action: "status_change", EntityType: "investigation", EntityID: investigations[4].ID, Before: `{"status":"In Progress"}`, After: `{"status":"Under Review"}`, Notes: "Investigation complete, submitted for Safety Manager review"},

		// CAPA 12 (Verified Ineffective) — full lifecycle
		{Timestamp: now.AddDate(0, -9, 0), UserID: "dev-safety_manager", UserRole: "safety_manager", Action: "create", EntityType: "capa", EntityID: capas[11].ID, Before: "", After: `{"type":"Corrective","priority":"Medium","status":"Open"}`, Notes: "Concrete washout containment CAPA created"},
		{Timestamp: now.AddDate(0, -8, 5), UserID: "dev-safety_coordinator_2", UserRole: "safety_coordinator", Action: "status_change", EntityType: "capa", EntityID: capas[11].ID, Before: `{"status":"In Progress"}`, After: `{"status":"Completed"}`, Notes: "Berm raised. Evidence uploaded."},
		{Timestamp: now.AddDate(0, -7, 5), UserID: "dev-safety_manager", UserRole: "safety_manager", Action: "verify", EntityType: "capa", EntityID: capas[11].ID, Before: `{"status":"Verification Pending"}`, After: `{"status":"Verified Ineffective"}`, Notes: "Berm failed during next event. Concrete liner required."},
		{Timestamp: now.AddDate(0, -7, 5), UserID: "dev-safety_manager", UserRole: "safety_manager", Action: "create", EntityType: "capa", EntityID: capas[12].ID, Before: "", After: `{"type":"Corrective","priority":"High","status":"Open"}`, Notes: "Follow-up CAPA created after ineffective verification"},

		// Settings change
		{Timestamp: now.AddDate(0, -2, 0), UserID: "dev-admin", UserRole: "admin", Action: "update", EntityType: "setting", EntityID: 1, Before: `{"key":"trir_benchmark","value":"3.5"}`, After: `{"key":"trir_benchmark","value":"3.0"}`, Notes: "Benchmark adjusted to industry average"},

		// Incident link creation
		{Timestamp: now.AddDate(0, -3, 5), UserID: "dev-safety_coordinator", UserRole: "safety_coordinator", Action: "create", EntityType: "incident_link", EntityID: incidentLinks[2].ID, Before: "", After: `{"similarityType":"Same Root Cause","incidentId1":7,"incidentId2":17}`, Notes: "Linked utility strike incidents sharing common root cause"},
	}

	db.Create(&auditLogs)

	log.Println("Seed: demo data populated successfully")
}
