package handlers

import (
	"encoding/json"
	"math"
	"net/http"
	"strconv"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// ---------- response types ----------

// DashboardResponse is the top-level JSON structure returned by GET /api/dashboard.
type DashboardResponse struct {
	TRIR                 float64                `json:"trir"`
	TRIRPrevious         float64                `json:"trirPrevious"`
	DARTRate             float64                `json:"dartRate"`
	NearMissRatio        float64                `json:"nearMissRatio"`
	OpenInvestigations   int64                  `json:"openInvestigations"`
	OpenCAPAs            int64                  `json:"openCapas"`
	LostWorkDaysYTD      int64                  `json:"lostWorkDaysYtd"`
	TRIRTrend            []MonthlyTRIR          `json:"trirTrend"`
	TRIRBenchmark        float64                `json:"trirBenchmark"`
	IncidentTrend        []MonthlyIncidentTrend `json:"incidentTrend"`
	IncidentsByDivision  []DivisionCount        `json:"incidentsByDivision"`
	SeverityDistribution []SeverityCount        `json:"severityDistribution"`
	LeadingIndicators    LeadingIndicators      `json:"leadingIndicators"`
	RecentIncidents      []RecentIncident       `json:"recentIncidents"`
}

// MonthlyTRIR holds a single month's TRIR value for the trend chart.
type MonthlyTRIR struct {
	Month string  `json:"month"` // "2025-06"
	TRIR  float64 `json:"trir"`
}

// MonthlyIncidentTrend holds stacked-bar data for one month.
type MonthlyIncidentTrend struct {
	Month          string `json:"month"`
	Injury         int64  `json:"injury"`
	NearMiss       int64  `json:"nearMiss"`
	PropertyDamage int64  `json:"propertyDamage"`
	Environmental  int64  `json:"environmental"`
	Vehicle        int64  `json:"vehicle"`
	Fire           int64  `json:"fire"`
	UtilityStrike  int64  `json:"utilityStrike"`
}

// DivisionCount groups incident count by division.
type DivisionCount struct {
	Division string `json:"division"`
	Count    int64  `json:"count"`
}

// SeverityCount groups incident count by severity.
type SeverityCount struct {
	Severity string `json:"severity"`
	Count    int64  `json:"count"`
}

// LeadingIndicators holds target-vs-actual for three leading metrics.
type LeadingIndicators struct {
	NearMissReportingRate   IndicatorMetric `json:"nearMissReportingRate"`
	CAPAClosureRate         IndicatorMetric `json:"capaClosureRate"`
	InvestigationTimeliness IndicatorMetric `json:"investigationTimeliness"`
}

// IndicatorMetric represents a target vs actual pair.
type IndicatorMetric struct {
	Target float64 `json:"target"`
	Actual float64 `json:"actual"`
}

// RecentIncident is a lightweight incident summary for the dashboard table.
type RecentIncident struct {
	ID       uint   `json:"id"`
	Date     string `json:"date"`
	Type     string `json:"type"`
	Severity string `json:"severity"`
	Status   string `json:"status"`
	Division string `json:"division"`
}

// ---------- GET /api/dashboard ----------

// GetDashboard returns comprehensive safety dashboard data.
func GetDashboard(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		now := time.Now()
		yearStart := time.Date(now.Year(), 1, 1, 0, 0, 0, 0, time.UTC)
		twelveMonthsAgo := now.AddDate(-1, 0, 0)

		// ---- Total Hours Worked (all time for current period) ----
		var totalHours float64
		db.Model(&models.HoursWorked{}).
			Select("COALESCE(SUM(total_hours), 0)").
			Scan(&totalHours)

		// ---- Hours this year for YTD calcs ----
		var totalHoursYTD float64
		db.Model(&models.HoursWorked{}).
			Where("reporting_period_start >= ?", yearStart).
			Select("COALESCE(SUM(total_hours), 0)").
			Scan(&totalHoursYTD)

		// ---- Recordable Incidents (non-draft, OSHA recordable) ----
		var recordableCount int64
		db.Model(&models.Incident{}).
			Where("is_osha_recordable = ? AND is_draft = ?", true, false).
			Count(&recordableCount)

		// ---- DART Cases ----
		var dartCount int64
		db.Model(&models.Incident{}).
			Where("is_dart = ? AND is_draft = ?", true, false).
			Count(&dartCount)

		// ---- Near Miss Reports ----
		var nearMissCount int64
		db.Model(&models.Incident{}).
			Where("type = ? AND is_draft = ?", "Near Miss", false).
			Count(&nearMissCount)

		// ---- Compute TRIR, DART, Near Miss Ratio ----
		trir := 0.0
		if totalHours > 0 {
			trir = (float64(recordableCount) * 200000) / totalHours
		}

		dartRate := 0.0
		if totalHours > 0 {
			dartRate = (float64(dartCount) * 200000) / totalHours
		}

		nearMissRatio := 0.0
		if recordableCount > 0 {
			nearMissRatio = float64(nearMissCount) / float64(recordableCount)
		}

		// Round to 2 decimal places
		trir = math.Round(trir*100) / 100
		dartRate = math.Round(dartRate*100) / 100
		nearMissRatio = math.Round(nearMissRatio*100) / 100

		// ---- TRIR Previous Period (for trend arrow) ----
		// Previous = from 24 months ago to 12 months ago
		twentyFourMonthsAgo := now.AddDate(-2, 0, 0)
		var prevHours float64
		db.Model(&models.HoursWorked{}).
			Where("reporting_period_start >= ? AND reporting_period_end < ?", twentyFourMonthsAgo, twelveMonthsAgo).
			Select("COALESCE(SUM(total_hours), 0)").
			Scan(&prevHours)

		var prevRecordable int64
		db.Model(&models.Incident{}).
			Where("is_osha_recordable = ? AND is_draft = ? AND date >= ? AND date < ?", true, false, twentyFourMonthsAgo, twelveMonthsAgo).
			Count(&prevRecordable)

		trirPrevious := 0.0
		if prevHours > 0 {
			trirPrevious = (float64(prevRecordable) * 200000) / prevHours
		}
		trirPrevious = math.Round(trirPrevious*100) / 100

		// ---- Open Investigations ----
		var openInvestigations int64
		db.Model(&models.Investigation{}).
			Where("status NOT IN ?", []string{"Approved"}).
			Count(&openInvestigations)

		// ---- Open CAPAs ----
		var openCAPAs int64
		db.Model(&models.CAPA{}).
			Where("status NOT IN ?", []string{"Verified Effective", "Verified Ineffective"}).
			Count(&openCAPAs)

		// ---- Lost Work Days YTD ----
		// Count incidents this year where severity indicates lost time
		var lostWorkDaysYTD int64
		db.Model(&models.Incident{}).
			Where("is_draft = ? AND date >= ? AND (severity = ? OR severity = ?)", false, yearStart, "Lost Time", "Fatality").
			Count(&lostWorkDaysYTD)

		// ---- TRIR Benchmark from settings ----
		trirBenchmark := 3.0
		var benchmarkSetting models.Setting
		if err := db.Where("key = ?", "trir_benchmark").First(&benchmarkSetting).Error; err == nil {
			if v, err := strconv.ParseFloat(benchmarkSetting.Value, 64); err == nil {
				trirBenchmark = v
			}
		}

		// ---- TRIR Trend (last 12 months) ----
		trirTrend := make([]MonthlyTRIR, 0, 12)
		for i := 11; i >= 0; i-- {
			mStart := time.Date(now.Year(), now.Month()-time.Month(i), 1, 0, 0, 0, 0, time.UTC)
			mEnd := mStart.AddDate(0, 1, 0)
			monthLabel := mStart.Format("2006-01")

			var mHours float64
			db.Model(&models.HoursWorked{}).
				Where("reporting_period_start >= ? AND reporting_period_end <= ?", mStart, mEnd).
				Select("COALESCE(SUM(total_hours), 0)").
				Scan(&mHours)

			var mRecordable int64
			db.Model(&models.Incident{}).
				Where("is_osha_recordable = ? AND is_draft = ? AND date >= ? AND date < ?", true, false, mStart, mEnd).
				Count(&mRecordable)

			mTRIR := 0.0
			if mHours > 0 {
				mTRIR = (float64(mRecordable) * 200000) / mHours
			}
			mTRIR = math.Round(mTRIR*100) / 100

			trirTrend = append(trirTrend, MonthlyTRIR{
				Month: monthLabel,
				TRIR:  mTRIR,
			})
		}

		// ---- Incident Trend by Month (stacked bar) ----
		incidentTypes := []string{"Injury", "Near Miss", "Property Damage", "Environmental", "Vehicle", "Fire", "Utility Strike"}
		incidentTrend := make([]MonthlyIncidentTrend, 0, 12)
		for i := 11; i >= 0; i-- {
			mStart := time.Date(now.Year(), now.Month()-time.Month(i), 1, 0, 0, 0, 0, time.UTC)
			mEnd := mStart.AddDate(0, 1, 0)
			monthLabel := mStart.Format("2006-01")

			counts := make(map[string]int64)
			for _, t := range incidentTypes {
				var c int64
				db.Model(&models.Incident{}).
					Where("type = ? AND is_draft = ? AND date >= ? AND date < ?", t, false, mStart, mEnd).
					Count(&c)
				counts[t] = c
			}

			incidentTrend = append(incidentTrend, MonthlyIncidentTrend{
				Month:          monthLabel,
				Injury:         counts["Injury"],
				NearMiss:       counts["Near Miss"],
				PropertyDamage: counts["Property Damage"],
				Environmental:  counts["Environmental"],
				Vehicle:        counts["Vehicle"],
				Fire:           counts["Fire"],
				UtilityStrike:  counts["Utility Strike"],
			})
		}

		// ---- Incidents by Division ----
		type divRow struct {
			Division string
			Count    int64
		}
		var divRows []divRow
		db.Model(&models.Incident{}).
			Select("division, COUNT(*) as count").
			Where("is_draft = ? AND division != '' AND date >= ?", false, twelveMonthsAgo).
			Group("division").
			Order("count DESC").
			Scan(&divRows)

		incidentsByDivision := make([]DivisionCount, 0, len(divRows))
		for _, dr := range divRows {
			incidentsByDivision = append(incidentsByDivision, DivisionCount{
				Division: dr.Division,
				Count:    dr.Count,
			})
		}

		// ---- Severity Distribution ----
		type sevRow struct {
			Severity string
			Count    int64
		}
		var sevRows []sevRow
		db.Model(&models.Incident{}).
			Select("severity, COUNT(*) as count").
			Where("is_draft = ? AND severity != '' AND date >= ?", false, twelveMonthsAgo).
			Group("severity").
			Order("count DESC").
			Scan(&sevRows)

		severityDistribution := make([]SeverityCount, 0, len(sevRows))
		for _, sr := range sevRows {
			severityDistribution = append(severityDistribution, SeverityCount{
				Severity: sr.Severity,
				Count:    sr.Count,
			})
		}

		// ---- Leading Indicators ----
		// Near Miss Reporting Rate — target: 10 near misses per recordable
		nearMissTarget := 10.0
		nearMissActual := nearMissRatio

		// CAPA Closure Rate — percentage of completed + verified CAPAs
		var totalCAPAs int64
		var closedCAPAs int64
		db.Model(&models.CAPA{}).Count(&totalCAPAs)
		db.Model(&models.CAPA{}).Where("status IN ?", []string{"Verified Effective", "Verified Ineffective", "Completed", "Verification Pending"}).Count(&closedCAPAs)
		capaClosureTarget := 90.0
		capaClosureActual := 0.0
		if totalCAPAs > 0 {
			capaClosureActual = math.Round((float64(closedCAPAs)/float64(totalCAPAs))*10000) / 100
		}

		// Investigation Timeliness — percentage completed on time
		var totalInvestigations int64
		var onTimeInvestigations int64
		db.Model(&models.Investigation{}).Where("status = ?", "Approved").Count(&totalInvestigations)
		db.Model(&models.Investigation{}).
			Where("status = ? AND (actual_completion_date IS NOT NULL AND actual_completion_date <= target_completion_date)", "Approved").
			Count(&onTimeInvestigations)
		investigationTarget := 95.0
		investigationActual := 0.0
		if totalInvestigations > 0 {
			investigationActual = math.Round((float64(onTimeInvestigations)/float64(totalInvestigations))*10000) / 100
		}

		leadingIndicators := LeadingIndicators{
			NearMissReportingRate: IndicatorMetric{
				Target: nearMissTarget,
				Actual: nearMissActual,
			},
			CAPAClosureRate: IndicatorMetric{
				Target: capaClosureTarget,
				Actual: capaClosureActual,
			},
			InvestigationTimeliness: IndicatorMetric{
				Target: investigationTarget,
				Actual: investigationActual,
			},
		}

		// ---- Recent 10 Incidents ----
		var incidents []models.Incident
		db.Where("is_draft = ?", false).
			Order("date DESC").
			Limit(10).
			Find(&incidents)

		recentIncidents := make([]RecentIncident, 0, len(incidents))
		for _, inc := range incidents {
			recentIncidents = append(recentIncidents, RecentIncident{
				ID:       inc.ID,
				Date:     inc.Date.Format("2006-01-02"),
				Type:     inc.Type,
				Severity: inc.Severity,
				Status:   inc.Status,
				Division: inc.Division,
			})
		}

		// ---- Assemble response ----
		resp := DashboardResponse{
			TRIR:                 trir,
			TRIRPrevious:         trirPrevious,
			DARTRate:             dartRate,
			NearMissRatio:        nearMissRatio,
			OpenInvestigations:   openInvestigations,
			OpenCAPAs:            openCAPAs,
			LostWorkDaysYTD:      lostWorkDaysYTD,
			TRIRTrend:            trirTrend,
			TRIRBenchmark:        trirBenchmark,
			IncidentTrend:        incidentTrend,
			IncidentsByDivision:  incidentsByDivision,
			SeverityDistribution: severityDistribution,
			LeadingIndicators:    leadingIndicators,
			RecentIncidents:      recentIncidents,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// ---------- POST /api/hours-worked ----------

// CreateHoursWorked lets a Safety Manager enter hours per reporting period.
func CreateHoursWorked(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		if userRole != "safety_manager" && userRole != "admin" {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		var hw models.HoursWorked
		if err := json.NewDecoder(r.Body).Decode(&hw); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if hw.TotalHours <= 0 {
			http.Error(w, "totalHours must be positive", http.StatusBadRequest)
			return
		}
		if hw.ReportingPeriodStart.IsZero() || hw.ReportingPeriodEnd.IsZero() {
			http.Error(w, "reporting period dates are required", http.StatusBadRequest)
			return
		}
		if hw.ReportingPeriodEnd.Before(hw.ReportingPeriodStart) {
			http.Error(w, "period end must be after period start", http.StatusBadRequest)
			return
		}

		hw.EnteredByUserID = userID

		if err := db.Create(&hw).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "create", "hours_worked", hw.ID, "", toJSON(hw), "")

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(hw)
	}
}

// ---------- GET /api/hours-worked ----------

// ListHoursWorked returns all hours-worked entries, newest first.
func ListHoursWorked(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var entries []models.HoursWorked
		if err := db.Order("reporting_period_start DESC").Find(&entries).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(entries)
	}
}

// ---------- route registration ----------

// RegisterDashboardRoutes wires up dashboard and hours-worked endpoints.
func RegisterDashboardRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("GET /api/dashboard", GetDashboard(db))
	api.HandleFunc("POST /api/hours-worked", CreateHoursWorked(db))
	api.HandleFunc("GET /api/hours-worked", ListHoursWorked(db))
}
