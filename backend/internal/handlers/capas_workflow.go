package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// ---------- Complete ----------

// completeCAPARequest is the JSON body for POST /api/capas/{id}/complete.
type completeCAPARequest struct {
	Notes    string `json:"notes"`
	Evidence string `json:"evidence"`
}

// CompleteCAPA handles POST /api/capas/{id}/complete.
// Status transitions: current status -> "Completed" -> "Verification Pending".
// Sets CompletionDate=now, auto-calculates VerificationDueDate by priority.
// Executive role is blocked (read-only).
func CompleteCAPA(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		// RBAC: Executive is read-only.
		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		id := r.PathValue("id")
		var capa models.CAPA
		if err := db.First(&capa, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// Only Open or In Progress CAPAs can be completed.
		if capa.Status != "Open" && capa.Status != "In Progress" {
			http.Error(w, "only Open or In Progress CAPAs can be completed", http.StatusBadRequest)
			return
		}

		var req completeCAPARequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		beforeJSON := toJSON(capa)

		now := time.Now()
		verificationDue := now.AddDate(0, 0, capaVerificationDueDays(capa.Priority))

		capa.Status = "Verification Pending"
		capa.CompletionNotes = req.Notes
		capa.CompletionEvidence = req.Evidence
		capa.CompletionDate = &now
		capa.VerificationDueDate = &verificationDue

		if err := db.Save(&capa).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "status_change", "capa", capa.ID, beforeJSON, toJSON(capa),
			fmt.Sprintf("CAPA completed, verification due %s", verificationDue.Format("2006-01-02")), isAgent)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(capa)
	}
}

// ---------- Verify ----------

// verifyCAPARequest is the JSON body for POST /api/capas/{id}/verify.
type verifyCAPARequest struct {
	Effective bool   `json:"effective"`
	Notes     string `json:"notes"`
}

// VerifyCAPA handles POST /api/capas/{id}/verify.
// CRITICAL: Reject if verifier == assignee (return 403).
// effective=true -> "Verified Effective"; effective=false -> "Verified Ineffective".
// Executive role is blocked (read-only).
func VerifyCAPA(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		// RBAC: Executive is read-only.
		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		id := r.PathValue("id")
		var capa models.CAPA
		if err := db.First(&capa, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// Only Verification Pending CAPAs can be verified.
		if capa.Status != "Verification Pending" {
			http.Error(w, "only Verification Pending CAPAs can be verified", http.StatusBadRequest)
			return
		}

		// CRITICAL: verifier must NOT be the assignee.
		if userID == capa.AssignedToUserID {
			http.Error(w, "forbidden: verifier cannot be the same user as the CAPA assignee", http.StatusForbidden)
			return
		}

		var req verifyCAPARequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		beforeJSON := toJSON(capa)

		now := time.Now()
		capa.VerifiedByUserID = userID
		capa.VerificationDate = &now
		capa.VerificationNotes = req.Notes

		if req.Effective {
			capa.Status = "Verified Effective"
		} else {
			capa.Status = "Verified Ineffective"
		}

		// Clear overdue since verification is complete.
		capa.IsOverdue = false
		capa.OverdueEscalationLevel = 0

		if err := db.Save(&capa).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "status_change", "capa", capa.ID, beforeJSON, toJSON(capa),
			fmt.Sprintf("CAPA verified as %s", capa.Status), isAgent)

		// Build response. For ineffective CAPAs, include prompt for next steps.
		response := map[string]interface{}{
			"capa": capa,
		}
		if !req.Effective {
			response["nextSteps"] = map[string]interface{}{
				"message":             "This CAPA was verified as ineffective. Consider creating a new CAPA or reopening the investigation.",
				"createNewCAPA":       true,
				"reopenInvestigation": true,
				"investigationId":     capa.InvestigationID,
				"incidentId":          capa.IncidentID,
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}
}

// ---------- Dashboard ----------

// capaDashboardResponse is the JSON response for GET /api/capas/dashboard.
type capaDashboardResponse struct {
	OpenCAPAs         int64   `json:"openCapas"`
	OverdueCAPAs      int64   `json:"overdueCapas"`
	AvgTimeToClose    float64 `json:"avgTimeToCloseDays"`
	EffectivenessRate float64 `json:"effectivenessRate"`
}

// CAPADashboard handles GET /api/capas/dashboard.
// Returns aggregated KPIs: open count, overdue count, average time to close,
// and effectiveness rate.
func CAPADashboard(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var resp capaDashboardResponse

		// Open CAPAs: status is Open or In Progress.
		db.Model(&models.CAPA{}).
			Where("status IN ?", []string{"Open", "In Progress"}).
			Count(&resp.OpenCAPAs)

		// Overdue CAPAs: refresh overdue status for active CAPAs first.
		// We query active CAPAs and update their overdue flags.
		var activeCAPAs []models.CAPA
		db.Where("status IN ?", []string{"Open", "In Progress", "Verification Pending"}).
			Find(&activeCAPAs)
		for i := range activeCAPAs {
			updateCAPAOverdueStatus(&activeCAPAs[i])
			db.Model(&activeCAPAs[i]).Updates(map[string]interface{}{
				"is_overdue":               activeCAPAs[i].IsOverdue,
				"overdue_escalation_level": activeCAPAs[i].OverdueEscalationLevel,
			})
		}
		db.Model(&models.CAPA{}).Where("is_overdue = ?", true).Count(&resp.OverdueCAPAs)

		// Average time to close: days from CreatedAt to VerificationDate for
		// Verified Effective CAPAs.
		var closedCAPAs []models.CAPA
		db.Where("status = ? AND verification_date IS NOT NULL", "Verified Effective").
			Find(&closedCAPAs)
		if len(closedCAPAs) > 0 {
			var totalDays float64
			for _, c := range closedCAPAs {
				totalDays += c.VerificationDate.Sub(c.CreatedAt).Hours() / 24
			}
			resp.AvgTimeToClose = totalDays / float64(len(closedCAPAs))
		}

		// Effectiveness rate: Verified Effective / (Verified Effective + Verified Ineffective) * 100.
		var effectiveCount int64
		var ineffectiveCount int64
		db.Model(&models.CAPA{}).Where("status = ?", "Verified Effective").Count(&effectiveCount)
		db.Model(&models.CAPA{}).Where("status = ?", "Verified Ineffective").Count(&ineffectiveCount)
		total := effectiveCount + ineffectiveCount
		if total > 0 {
			resp.EffectivenessRate = float64(effectiveCount) / float64(total) * 100
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
