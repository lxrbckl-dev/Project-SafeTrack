package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// ---------- Five-Why CRUD ----------

// CreateOrUpdateFiveWhy handles POST /api/investigations/{id}/five-whys.
// If the body contains an ID, updates the existing entry; otherwise creates new.
func CreateOrUpdateFiveWhy(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		investigationID := r.PathValue("id")

		// Verify the investigation exists.
		var investigation models.Investigation
		if err := db.First(&investigation, investigationID).Error; err != nil {
			http.Error(w, "investigation not found", http.StatusNotFound)
			return
		}

		var fiveWhy models.FiveWhy
		if err := json.NewDecoder(r.Body).Decode(&fiveWhy); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		fiveWhy.InvestigationID = investigation.ID

		if fiveWhy.ID != 0 {
			// Update existing five-why entry.
			var existing models.FiveWhy
			if err := db.Where("id = ? AND investigation_id = ?", fiveWhy.ID, investigation.ID).First(&existing).Error; err != nil {
				http.Error(w, "five-why entry not found", http.StatusNotFound)
				return
			}

			beforeJSON := toJSON(existing)
			existing.Level = fiveWhy.Level
			existing.Question = fiveWhy.Question
			existing.Answer = fiveWhy.Answer
			existing.Evidence = fiveWhy.Evidence
			existing.SortOrder = fiveWhy.SortOrder

			if err := db.Save(&existing).Error; err != nil {
				http.Error(w, "database error", http.StatusInternalServerError)
				return
			}

			LogAction(db, userID, userRole, "update", "five_why", existing.ID, beforeJSON, toJSON(existing), "")

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(existing)
			return
		}

		// Create new five-why entry. Auto-set SortOrder if not provided.
		if fiveWhy.SortOrder == 0 {
			var maxSort int
			db.Model(&models.FiveWhy{}).
				Where("investigation_id = ?", investigation.ID).
				Select("COALESCE(MAX(sort_order), 0)").
				Scan(&maxSort)
			fiveWhy.SortOrder = maxSort + 1
		}

		if err := db.Create(&fiveWhy).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "create", "five_why", fiveWhy.ID, "", toJSON(fiveWhy), "")

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(fiveWhy)
	}
}

// DeleteFiveWhy handles DELETE /api/investigations/{id}/five-whys/{whyId}.
// Minimum 3 five-whys is enforced on submit, not on individual deletes.
func DeleteFiveWhy(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		investigationID := r.PathValue("id")
		whyID := r.PathValue("whyId")

		var fiveWhy models.FiveWhy
		if err := db.Where("id = ? AND investigation_id = ?", whyID, investigationID).First(&fiveWhy).Error; err != nil {
			http.Error(w, "five-why entry not found", http.StatusNotFound)
			return
		}

		LogAction(db, userID, userRole, "delete", "five_why", fiveWhy.ID, toJSON(fiveWhy), "", "")

		if err := db.Delete(&fiveWhy).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

// ---------- Contributing Factors ----------

// CreateContributingFactor handles POST /api/investigations/{id}/factors.
func CreateContributingFactor(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		investigationID := r.PathValue("id")

		var investigation models.Investigation
		if err := db.First(&investigation, investigationID).Error; err != nil {
			http.Error(w, "investigation not found", http.StatusNotFound)
			return
		}

		var factor models.ContributingFactor
		if err := json.NewDecoder(r.Body).Decode(&factor); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		factor.InvestigationID = investigation.ID

		if factor.FactorType == "" {
			http.Error(w, "factorType is required", http.StatusBadRequest)
			return
		}

		if err := db.Create(&factor).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "create", "contributing_factor", factor.ID, "", toJSON(factor), "")

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(factor)
	}
}

// DeleteContributingFactor handles DELETE /api/investigations/{id}/factors/{factorId}.
func DeleteContributingFactor(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		investigationID := r.PathValue("id")
		factorID := r.PathValue("factorId")

		var factor models.ContributingFactor
		if err := db.Where("id = ? AND investigation_id = ?", factorID, investigationID).First(&factor).Error; err != nil {
			http.Error(w, "contributing factor not found", http.StatusNotFound)
			return
		}

		LogAction(db, userID, userRole, "delete", "contributing_factor", factor.ID, toJSON(factor), "", "")

		if err := db.Delete(&factor).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

// ---------- Witness Statements ----------

// CreateWitnessStatement handles POST /api/investigations/{id}/witnesses.
func CreateWitnessStatement(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		investigationID := r.PathValue("id")

		var investigation models.Investigation
		if err := db.First(&investigation, investigationID).Error; err != nil {
			http.Error(w, "investigation not found", http.StatusNotFound)
			return
		}

		var statement models.WitnessStatement
		if err := json.NewDecoder(r.Body).Decode(&statement); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		statement.InvestigationID = investigation.ID

		if statement.WitnessName == "" || statement.StatementText == "" {
			http.Error(w, "witnessName and statementText are required", http.StatusBadRequest)
			return
		}

		if err := db.Create(&statement).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "create", "witness_statement", statement.ID, "", toJSON(statement), "")

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(statement)
	}
}

// UpdateWitnessStatement handles PUT /api/investigations/{id}/witnesses/{witnessId}.
func UpdateWitnessStatement(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		investigationID := r.PathValue("id")
		witnessID := r.PathValue("witnessId")

		var existing models.WitnessStatement
		if err := db.Where("id = ? AND investigation_id = ?", witnessID, investigationID).First(&existing).Error; err != nil {
			http.Error(w, "witness statement not found", http.StatusNotFound)
			return
		}

		beforeJSON := toJSON(existing)

		var updates models.WitnessStatement
		if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if updates.WitnessName != "" {
			existing.WitnessName = updates.WitnessName
		}
		if updates.WitnessTitle != "" {
			existing.WitnessTitle = updates.WitnessTitle
		}
		if updates.WitnessEmployer != "" {
			existing.WitnessEmployer = updates.WitnessEmployer
		}
		if updates.WitnessPhone != "" {
			existing.WitnessPhone = updates.WitnessPhone
		}
		if updates.StatementText != "" {
			existing.StatementText = updates.StatementText
		}
		if !updates.CollectionDate.IsZero() {
			existing.CollectionDate = updates.CollectionDate
		}
		if updates.CollectorName != "" {
			existing.CollectorName = updates.CollectorName
		}

		if err := db.Save(&existing).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "update", "witness_statement", existing.ID, beforeJSON, toJSON(existing), "")

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(existing)
	}
}

// ---------- Workflow ----------

// SubmitForReview handles POST /api/investigations/{id}/submit-for-review.
// Validates minimum 3 five-whys and at least 1 primary contributing factor.
func SubmitForReview(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		id := r.PathValue("id")
		var investigation models.Investigation
		if err := db.
			Preload("FiveWhys").
			Preload("ContributingFactors").
			First(&investigation, id).Error; err != nil {
			http.Error(w, "investigation not found", http.StatusNotFound)
			return
		}

		// Validate: minimum 3 five-whys.
		if len(investigation.FiveWhys) < 3 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "minimum 3 five-why entries required before submission",
			})
			return
		}

		// Validate: at least 1 primary contributing factor.
		hasPrimary := false
		for _, f := range investigation.ContributingFactors {
			if f.IsPrimary {
				hasPrimary = true
				break
			}
		}
		if !hasPrimary {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "at least one primary contributing factor is required before submission",
			})
			return
		}

		beforeJSON := toJSON(investigation)
		investigation.Status = "Under Review"

		if err := db.Save(&investigation).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "status_change", "investigation", investigation.ID, beforeJSON, toJSON(investigation), "Submitted for review")

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(investigation)
	}
}

// reviewRequest is the JSON body for POST /api/investigations/{id}/review.
type reviewRequest struct {
	Decision string `json:"decision"` // "approve" or "return"
	Comments string `json:"comments"`
}

// ReviewInvestigation handles POST /api/investigations/{id}/review.
// Safety Manager only. Approves or returns an investigation.
func ReviewInvestigation(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		// RBAC: Safety Manager only.
		if userRole != "safety_manager" && userRole != "admin" {
			http.Error(w, "forbidden: only Safety Manager can review investigations", http.StatusForbidden)
			return
		}

		id := r.PathValue("id")
		var investigation models.Investigation
		if err := db.First(&investigation, id).Error; err != nil {
			http.Error(w, "investigation not found", http.StatusNotFound)
			return
		}

		if investigation.Status != "Under Review" {
			http.Error(w, "investigation must be Under Review to review", http.StatusBadRequest)
			return
		}

		var req reviewRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if req.Decision != "approve" && req.Decision != "return" {
			http.Error(w, "decision must be 'approve' or 'return'", http.StatusBadRequest)
			return
		}

		if req.Comments == "" {
			http.Error(w, "comments are required for review", http.StatusBadRequest)
			return
		}

		beforeJSON := toJSON(investigation)
		now := time.Now()

		investigation.ReviewedBy = userID
		investigation.ReviewDate = &now
		investigation.ReviewComments = req.Comments

		switch req.Decision {
		case "approve":
			investigation.Status = "Approved"
			investigation.ActualCompletionDate = &now

			if err := db.Save(&investigation).Error; err != nil {
				http.Error(w, "database error", http.StatusInternalServerError)
				return
			}

			// Update incident status to "Investigation Complete".
			var incident models.Incident
			if err := db.First(&incident, investigation.IncidentID).Error; err == nil {
				incidentBefore := toJSON(incident)
				incident.Status = "Investigation Complete"
				db.Save(&incident)
				LogAction(db, userID, userRole, "status_change", "incident", incident.ID, incidentBefore, toJSON(incident), "Investigation approved")
			}

			LogAction(db, userID, userRole, "approve", "investigation", investigation.ID, beforeJSON, toJSON(investigation), req.Comments)

		case "return":
			investigation.Status = "Returned"

			if err := db.Save(&investigation).Error; err != nil {
				http.Error(w, "database error", http.StatusInternalServerError)
				return
			}

			LogAction(db, userID, userRole, "return", "investigation", investigation.ID, beforeJSON, toJSON(investigation), req.Comments)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(investigation)
	}
}
