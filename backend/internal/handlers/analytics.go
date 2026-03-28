package handlers

import (
	"encoding/json"
	"math"
	"net/http"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/crypto"
	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// ---------- response types ----------

// BodyPartCount holds the aggregated count of injuries by body part.
type BodyPartCount struct {
	BodyPart string `json:"bodyPart"`
	Count    int    `json:"count"`
}

// TimeHeatmapCell holds the incident count for a specific hour-of-day and day-of-week.
type TimeHeatmapCell struct {
	Hour  int    `json:"hour"`
	Day   string `json:"day"`
	Count int    `json:"count"`
}

// DivisionRadarEntry holds multi-metric data for a single division.
type DivisionRadarEntry struct {
	Division                string  `json:"division"`
	Incidents               int     `json:"incidents"`
	TRIR                    float64 `json:"trir"`
	InvestigationTimeliness float64 `json:"investigationTimeliness"`
	CAPAClosureRate         float64 `json:"capaClosureRate"`
}

// ---------- GET /api/dashboard/body-map ----------

// GetBodyMap aggregates injury counts by body part. It decrypts the encrypted
// BodyPart field on InjuredPerson records to build the aggregation, but only
// returns counts — never raw medical data.
// Requires Safety Coordinator role or above.
func GetBodyMap(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := middleware.GetUserRole(r)
		if !canViewMedicalData(userRole) {
			http.Error(w, "forbidden: requires Safety Coordinator or above", http.StatusForbidden)
			return
		}

		// Fetch all injured persons (only encrypted body part + side fields)
		var persons []models.InjuredPerson
		if err := db.Select("body_part, body_part_side").Find(&persons).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Decrypt and aggregate
		counts := make(map[string]int)
		for _, p := range persons {
			if p.BodyPart == "" {
				continue
			}
			decrypted, err := crypto.Decrypt(p.BodyPart)
			if err != nil || decrypted == "" {
				continue
			}
			counts[decrypted]++
		}

		// Convert to sorted slice
		result := make([]BodyPartCount, 0, len(counts))
		for bp, c := range counts {
			result = append(result, BodyPartCount{BodyPart: bp, Count: c})
		}

		// Sort by count descending for consistent output
		sortBodyPartCounts(result)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)
	}
}

// sortBodyPartCounts sorts by count descending, then by name ascending.
func sortBodyPartCounts(counts []BodyPartCount) {
	for i := 0; i < len(counts); i++ {
		for j := i + 1; j < len(counts); j++ {
			if counts[j].Count > counts[i].Count ||
				(counts[j].Count == counts[i].Count && counts[j].BodyPart < counts[i].BodyPart) {
				counts[i], counts[j] = counts[j], counts[i]
			}
		}
	}
}

// canViewMedicalData returns true for roles allowed to see medical aggregates.
func canViewMedicalData(role string) bool {
	switch role {
	case "safety_coordinator", "safety_manager", "admin":
		return true
	default:
		return false
	}
}

// ---------- GET /api/dashboard/time-heatmap ----------

// GetTimeHeatmap returns incident counts grouped by hour-of-day (0-23) and
// day-of-week (Monday through Sunday). Only non-draft incidents from the
// last 12 months are included.
func GetTimeHeatmap(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		twelveMonthsAgo := time.Now().AddDate(-1, 0, 0)

		var incidents []models.Incident
		if err := db.Select("date").
			Where("is_draft = ? AND date >= ?", false, twelveMonthsAgo).
			Find(&incidents).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Initialize the full 24 x 7 grid
		dayNames := []string{"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
		grid := make(map[int]map[string]int) // hour -> day -> count
		for h := 0; h < 24; h++ {
			grid[h] = make(map[string]int)
			for _, d := range dayNames {
				grid[h][d] = 0
			}
		}

		// Aggregate
		for _, inc := range incidents {
			hour := inc.Date.Hour()
			day := inc.Date.Weekday()
			dayName := weekdayToName(day)
			grid[hour][dayName]++
		}

		// Flatten to response
		result := make([]TimeHeatmapCell, 0, 24*7)
		for h := 0; h < 24; h++ {
			for _, d := range dayNames {
				result = append(result, TimeHeatmapCell{
					Hour:  h,
					Day:   d,
					Count: grid[h][d],
				})
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)
	}
}

// weekdayToName converts Go's time.Weekday to our standard day name.
func weekdayToName(w time.Weekday) string {
	switch w {
	case time.Monday:
		return "Monday"
	case time.Tuesday:
		return "Tuesday"
	case time.Wednesday:
		return "Wednesday"
	case time.Thursday:
		return "Thursday"
	case time.Friday:
		return "Friday"
	case time.Saturday:
		return "Saturday"
	case time.Sunday:
		return "Sunday"
	default:
		return "Unknown"
	}
}

// ---------- GET /api/dashboard/division-radar ----------

// GetDivisionRadar returns multi-metric comparison data across divisions:
// incident count, TRIR, investigation timeliness, and CAPA closure rate.
// Only non-draft incidents from the last 12 months are considered.
// Uses bulk GROUP BY queries to avoid N+1 query patterns.
func GetDivisionRadar(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		twelveMonthsAgo := time.Now().AddDate(-1, 0, 0)
		yearStart := time.Date(time.Now().Year(), 1, 1, 0, 0, 0, 0, time.UTC)

		// --- Query 1: incident counts per division (last 12 months) ---
		type divRow struct {
			Division string
			Count    int
		}
		var divRows []divRow
		db.Model(&models.Incident{}).
			Select("division, COUNT(*) as count").
			Where("is_draft = ? AND division != '' AND date >= ?", false, twelveMonthsAgo).
			Group("division").
			Order("count DESC").
			Scan(&divRows)

		if len(divRows) == 0 {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode([]DivisionRadarEntry{})
			return
		}

		// Build ordered division list and index for fast lookup
		divisions := make([]string, len(divRows))
		for i, dr := range divRows {
			divisions[i] = dr.Division
		}

		// --- Query 2: recordable incident count per division YTD ---
		type divCount struct {
			Division string
			Count    int64
		}
		var recordableCounts []divCount
		db.Model(&models.Incident{}).
			Select("division, COUNT(*) as count").
			Where("division IN ? AND is_osha_recordable = ? AND is_draft = ? AND date >= ?",
				divisions, true, false, yearStart).
			Group("division").
			Scan(&recordableCounts)

		recordableMap := make(map[string]int64, len(recordableCounts))
		for _, rc := range recordableCounts {
			recordableMap[rc.Division] = rc.Count
		}

		// --- Query 3: hours worked per division YTD ---
		type divHours struct {
			Division   string
			TotalHours float64
		}
		var hourRows []divHours
		db.Model(&models.HoursWorked{}).
			Select("division, COALESCE(SUM(total_hours), 0) as total_hours").
			Where("division IN ? AND reporting_period_start >= ?", divisions, yearStart).
			Group("division").
			Scan(&hourRows)

		hoursMap := make(map[string]float64, len(hourRows))
		for _, hr := range hourRows {
			hoursMap[hr.Division] = hr.TotalHours
		}

		// --- Query 4: investigation timeliness per division (via JOIN) ---
		// Join incidents → investigations so we can GROUP BY division in one pass.
		type invRow struct {
			Division string
			Total    int64
			OnTime   int64
		}
		var invRows []invRow
		db.Model(&models.Investigation{}).
			Select("incidents.division as division, COUNT(*) as total, "+
				"SUM(CASE WHEN investigations.actual_completion_date IS NOT NULL "+
				"AND investigations.actual_completion_date <= investigations.target_completion_date "+
				"THEN 1 ELSE 0 END) as on_time").
			Joins("JOIN incidents ON incidents.id = investigations.incident_id").
			Where("incidents.division IN ? AND incidents.is_draft = ? AND incidents.date >= ? AND investigations.status = ?",
				divisions, false, twelveMonthsAgo, "Approved").
			Group("incidents.division").
			Scan(&invRows)

		invMap := make(map[string]invRow, len(invRows))
		for _, iv := range invRows {
			invMap[iv.Division] = iv
		}

		// --- Query 5: CAPA closure rate per division (via JOIN) ---
		type capaRow struct {
			Division string
			Total    int64
			Closed   int64
		}
		var capaRows []capaRow
		closedStatuses := []string{"Verified Effective", "Verified Ineffective", "Completed", "Verification Pending"}
		db.Model(&models.CAPA{}).
			Select("incidents.division as division, COUNT(*) as total, "+
				"SUM(CASE WHEN capas.status IN ? THEN 1 ELSE 0 END) as closed", closedStatuses).
			Joins("JOIN incidents ON incidents.id = capas.incident_id").
			Where("incidents.division IN ? AND incidents.is_draft = ? AND incidents.date >= ?",
				divisions, false, twelveMonthsAgo).
			Group("incidents.division").
			Scan(&capaRows)

		capaMap := make(map[string]capaRow, len(capaRows))
		for _, cr := range capaRows {
			capaMap[cr.Division] = cr
		}

		// --- Assemble result from pre-fetched maps ---
		result := make([]DivisionRadarEntry, 0, len(divRows))
		for _, dr := range divRows {
			entry := DivisionRadarEntry{
				Division:  dr.Division,
				Incidents: dr.Count,
			}

			// TRIR
			if h := hoursMap[dr.Division]; h > 0 {
				entry.TRIR = math.Round((float64(recordableMap[dr.Division])*200000/h)*100) / 100
			}

			// Investigation timeliness
			if iv, ok := invMap[dr.Division]; ok && iv.Total > 0 {
				entry.InvestigationTimeliness = math.Round((float64(iv.OnTime)/float64(iv.Total))*10000) / 100
			}

			// CAPA closure rate
			if ca, ok := capaMap[dr.Division]; ok && ca.Total > 0 {
				entry.CAPAClosureRate = math.Round((float64(ca.Closed)/float64(ca.Total))*10000) / 100
			}

			result = append(result, entry)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)
	}
}

// ---------- route registration ----------

// RegisterAnalyticsRoutes wires up the advanced analytics endpoints.
func RegisterAnalyticsRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("GET /api/dashboard/body-map", GetBodyMap(db))
	api.HandleFunc("GET /api/dashboard/time-heatmap", GetTimeHeatmap(db))
	api.HandleFunc("GET /api/dashboard/division-radar", GetDivisionRadar(db))
}
