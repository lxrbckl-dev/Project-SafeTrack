package handlers

import (
	"encoding/csv"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// RegisterOSHARoutes wires up the three OSHA log export endpoints.
// All routes are restricted to Safety Manager and Admin roles.
func RegisterOSHARoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("GET /api/osha/300", OshaLog300(db))
	api.HandleFunc("GET /api/osha/300a", OshaLog300A(db))
	api.HandleFunc("GET /api/osha/301/{incidentId}", OshaLog301(db))
}

// canAccessOSHA returns true for Safety Manager and Admin roles only.
func canAccessOSHA(role string) bool {
	return role == "safety_manager" || role == "admin"
}

// oshaYear parses the ?year= query parameter, defaulting to the current year.
func oshaYear(r *http.Request) int {
	if raw := r.URL.Query().Get("year"); raw != "" {
		if y, err := strconv.Atoi(raw); err == nil && y > 0 {
			return y
		}
	}
	return time.Now().Year()
}

// yearRange returns the start and end of a calendar year in UTC.
func yearRange(year int) (time.Time, time.Time) {
	start := time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC)
	end := time.Date(year+1, 1, 1, 0, 0, 0, 0, time.UTC)
	return start, end
}

// classify returns the OSHA 300 column classification for an incident.
// Returns one of: "Death", "Days Away", "Transfer/Restriction", "Other Recordable".
func classify(incident *models.Incident) string {
	if incident.Type == "Injury" || len(incident.InjuredPersons) > 0 {
		// Use the DART flag to determine classification.
		if incident.IsDart != nil && *incident.IsDart {
			// Distinguish days-away from transfer by inspecting injury data.
			// Since we don't store separate day counts here, check TreatmentType.
			for _, p := range incident.InjuredPersons {
				if p.TreatmentType == "Hospitalization" || p.TreatmentType == "Emergency Room" {
					return "Days Away"
				}
				if p.TreatmentType == "Restricted Work" || p.TreatmentType == "Job Transfer" {
					return "Transfer/Restriction"
				}
			}
			return "Days Away"
		}
		// Check for death
		for _, p := range incident.InjuredPersons {
			if p.ReturnToWorkStatus == "Deceased" {
				return "Death"
			}
		}
	}
	return "Other Recordable"
}

// OshaLog300 handles GET /api/osha/300?year=YYYY.
// Returns a CSV-formatted OSHA Form 300 (Log of Work-Related Injuries and Illnesses)
// for all OSHA-recordable incidents in the given year.
// RBAC: Safety Manager + Admin only.
func OshaLog300(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := middleware.GetUserRole(r)
		if !canAccessOSHA(userRole) {
			http.Error(w, "forbidden: Safety Manager or Admin role required", http.StatusForbidden)
			return
		}

		year := oshaYear(r)
		start, end := yearRange(year)

		var incidents []models.Incident
		result := db.
			Preload("InjuredPersons").
			Where("is_osha_recordable = ? AND date >= ? AND date < ? AND is_draft = ?", true, start, end, false).
			Order("date asc").
			Find(&incidents)
		if result.Error != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Decrypt medical fields — OSHA logs are for authorized roles only.
		for i := range incidents {
			if len(incidents[i].InjuredPersons) > 0 {
				decryptInjuredPersons(incidents[i].InjuredPersons)
			}
		}

		filename := fmt.Sprintf("osha_300_%d.csv", year)
		w.Header().Set("Content-Type", "text/csv")
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))

		cw := csv.NewWriter(w)
		defer cw.Flush()

		// OSHA 300 header row
		_ = cw.Write([]string{
			"Case No",
			"Employee Name",
			"Job Title",
			"Date of Injury/Illness",
			"Where Event Occurred",
			"Describe Injury/Illness",
			"Classification",
			"Days Away from Work",
			"Days on Job Transfer/Restriction",
		})

		for _, inc := range incidents {
			caseNo := strconv.FormatUint(uint64(inc.ID), 10)
			dateStr := inc.Date.Format("01/02/2006")
			location := inc.Location
			if inc.ProjectJobSite != "" {
				location = inc.ProjectJobSite
			}
			classification := classify(&inc)

			if len(inc.InjuredPersons) == 0 {
				// Incident with no injured persons recorded — single row with blank person fields.
				_ = cw.Write([]string{
					caseNo,
					"",
					"",
					dateStr,
					location,
					inc.Description,
					classification,
					"",
					"",
				})
			} else {
				for _, person := range inc.InjuredPersons {
					// Determine days away / days transfer from return-to-work status.
					daysAway := ""
					daysTransfer := ""
					switch person.ReturnToWorkStatus {
					case "Restricted Work", "Job Transfer":
						daysTransfer = "1" // minimum; exact count not tracked in this model
					case "Away from Work":
						daysAway = "1"
					}

					_ = cw.Write([]string{
						caseNo,
						person.Name,
						person.JobTitle,
						dateStr,
						location,
						inc.Description,
						classification,
						daysAway,
						daysTransfer,
					})
				}
			}
		}
	}
}

// OshaLog300A handles GET /api/osha/300a?year=YYYY.
// Returns a CSV-formatted OSHA Form 300A (Annual Summary) aggregating totals
// across all OSHA-recordable incidents for the given year.
// RBAC: Safety Manager + Admin only.
func OshaLog300A(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := middleware.GetUserRole(r)
		if !canAccessOSHA(userRole) {
			http.Error(w, "forbidden: Safety Manager or Admin role required", http.StatusForbidden)
			return
		}

		year := oshaYear(r)
		start, end := yearRange(year)

		var incidents []models.Incident
		result := db.
			Preload("InjuredPersons").
			Where("is_osha_recordable = ? AND date >= ? AND date < ? AND is_draft = ?", true, start, end, false).
			Find(&incidents)
		if result.Error != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Decrypt medical fields to classify injury types.
		for i := range incidents {
			if len(incidents[i].InjuredPersons) > 0 {
				decryptInjuredPersons(incidents[i].InjuredPersons)
			}
		}

		// Aggregate 300A totals
		var (
			totalDeaths          int
			totalDaysAway        int
			totalTransfer        int
			totalOtherRecordable int
			totalInjuries        int
			totalSkinDisorders   int
			totalRespiratory     int
			totalPoisoning       int
			totalHearingLoss     int
			totalOtherIllnesses  int
			totalDaysAwayCount   int
			totalDaysTransfer    int
		)

		for _, inc := range incidents {
			cls := classify(&inc)
			switch cls {
			case "Death":
				totalDeaths++
			case "Days Away":
				totalDaysAway++
				totalDaysAwayCount++ // placeholder: 1 per case
			case "Transfer/Restriction":
				totalTransfer++
				totalDaysTransfer++ // placeholder: 1 per case
			default:
				totalOtherRecordable++
			}

			for _, person := range inc.InjuredPersons {
				switch person.InjuryType {
				case "Injury":
					totalInjuries++
				case "Skin Disorder":
					totalSkinDisorders++
				case "Respiratory Condition":
					totalRespiratory++
				case "Poisoning":
					totalPoisoning++
				case "Hearing Loss":
					totalHearingLoss++
				case "All Other Illnesses":
					totalOtherIllnesses++
				default:
					// Count unclassified injury-type incidents as injuries.
					totalInjuries++
				}
			}
		}

		filename := fmt.Sprintf("osha_300a_%d.csv", year)
		w.Header().Set("Content-Type", "text/csv")
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))

		cw := csv.NewWriter(w)
		defer cw.Flush()

		// 300A summary: two-column label/value format
		_ = cw.Write([]string{"OSHA Form 300A — Summary of Work-Related Injuries and Illnesses", fmt.Sprintf("Year: %d", year)})
		_ = cw.Write([]string{""})
		_ = cw.Write([]string{"Metric", "Total"})
		_ = cw.Write([]string{"Total Deaths", strconv.Itoa(totalDeaths)})
		_ = cw.Write([]string{"Total Cases with Days Away from Work", strconv.Itoa(totalDaysAway)})
		_ = cw.Write([]string{"Total Cases with Job Transfer or Restriction", strconv.Itoa(totalTransfer)})
		_ = cw.Write([]string{"Total Other Recordable Cases", strconv.Itoa(totalOtherRecordable)})
		_ = cw.Write([]string{""})
		_ = cw.Write([]string{"Total Number of Injuries", strconv.Itoa(totalInjuries)})
		_ = cw.Write([]string{"Total Skin Disorders", strconv.Itoa(totalSkinDisorders)})
		_ = cw.Write([]string{"Total Respiratory Conditions", strconv.Itoa(totalRespiratory)})
		_ = cw.Write([]string{"Total Poisonings", strconv.Itoa(totalPoisoning)})
		_ = cw.Write([]string{"Total Hearing Loss", strconv.Itoa(totalHearingLoss)})
		_ = cw.Write([]string{"Total Other Illnesses", strconv.Itoa(totalOtherIllnesses)})
		_ = cw.Write([]string{""})
		_ = cw.Write([]string{"Total Days Away from Work", strconv.Itoa(totalDaysAwayCount)})
		_ = cw.Write([]string{"Total Days of Job Transfer/Restriction", strconv.Itoa(totalDaysTransfer)})
	}
}

// OshaLog301 handles GET /api/osha/301/{incidentId}.
// Returns a CSV-formatted OSHA Form 301 (Injury and Illness Incident Report)
// for a single incident, including all injured person details.
// RBAC: Safety Manager + Admin only.
func OshaLog301(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := middleware.GetUserRole(r)
		if !canAccessOSHA(userRole) {
			http.Error(w, "forbidden: Safety Manager or Admin role required", http.StatusForbidden)
			return
		}

		incidentID := r.PathValue("incidentId")
		var incident models.Incident
		if err := db.Preload("InjuredPersons").First(&incident, incidentID).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// Only generate 301 for OSHA-recordable incidents.
		if incident.IsOshaRecordable == nil || !*incident.IsOshaRecordable {
			http.Error(w, "incident is not OSHA recordable", http.StatusBadRequest)
			return
		}

		// Decrypt medical fields.
		if len(incident.InjuredPersons) > 0 {
			decryptInjuredPersons(incident.InjuredPersons)
		}

		filename := fmt.Sprintf("osha_301_incident_%s.csv", incidentID)
		w.Header().Set("Content-Type", "text/csv")
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))

		cw := csv.NewWriter(w)
		defer cw.Flush()

		// Section 1 — Incident details
		_ = cw.Write([]string{"OSHA Form 301 — Injury and Illness Incident Report"})
		_ = cw.Write([]string{""})
		_ = cw.Write([]string{"SECTION 1 — INCIDENT INFORMATION"})
		_ = cw.Write([]string{"Case Number", strconv.FormatUint(uint64(incident.ID), 10)})
		_ = cw.Write([]string{"Incident Type", incident.Type})
		_ = cw.Write([]string{"Date of Injury/Illness", incident.Date.Format("01/02/2006")})
		_ = cw.Write([]string{"Time of Event (Shift)", incident.Shift})
		_ = cw.Write([]string{"Location Where Event Occurred", incident.Location})
		if incident.ProjectJobSite != "" {
			_ = cw.Write([]string{"Project / Job Site", incident.ProjectJobSite})
		}
		_ = cw.Write([]string{"Division", incident.Division})
		_ = cw.Write([]string{"Description of Event", incident.Description})
		_ = cw.Write([]string{"Immediate Actions Taken", incident.ImmediateActions})
		_ = cw.Write([]string{"Severity", incident.Severity})
		_ = cw.Write([]string{"Weather Conditions", incident.Weather})
		_ = cw.Write([]string{"OSHA Recordable", boolLabel(incident.IsOshaRecordable)})
		_ = cw.Write([]string{"DART Case", boolLabel(incident.IsDart)})
		if incident.OshaOverrideJustification != "" {
			_ = cw.Write([]string{"OSHA Override Justification", incident.OshaOverrideJustification})
		}
		_ = cw.Write([]string{"Status", incident.Status})
		_ = cw.Write([]string{"Reported At", incident.CreatedAt.Format("01/02/2006 15:04 UTC")})

		// Section 2 — Injured person details
		if len(incident.InjuredPersons) > 0 {
			_ = cw.Write([]string{""})
			_ = cw.Write([]string{"SECTION 2 — INJURED / ILL EMPLOYEE INFORMATION"})
			_ = cw.Write([]string{
				"Name",
				"Job Title",
				"Division",
				"Injury/Illness Type",
				"Body Part Affected",
				"Body Part Side",
				"Treatment Type",
				"Return-to-Work Status",
			})

			for _, person := range incident.InjuredPersons {
				_ = cw.Write([]string{
					person.Name,
					person.JobTitle,
					person.Division,
					person.InjuryType,
					person.BodyPart,
					person.BodyPartSide,
					person.TreatmentType,
					person.ReturnToWorkStatus,
				})
			}
		} else {
			_ = cw.Write([]string{""})
			_ = cw.Write([]string{"SECTION 2 — INJURED / ILL EMPLOYEE INFORMATION"})
			_ = cw.Write([]string{"No injured persons recorded for this incident."})
		}
	}
}

// boolLabel converts a *bool pointer to a human-readable "Yes" / "No" / "Not Determined".
func boolLabel(b *bool) string {
	if b == nil {
		return "Not Determined"
	}
	if *b {
		return "Yes"
	}
	return "No"
}
