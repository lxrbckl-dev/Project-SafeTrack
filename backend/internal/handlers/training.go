package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// trainingReadRoles lists roles allowed to view training requirements.
var trainingReadRoles = []string{
	"safety_coordinator", "safety_manager", "pm", "division_manager", "executive", "admin",
}

// trainingWriteRoles lists roles allowed to create and complete training.
var trainingWriteRoles = []string{
	"safety_coordinator", "safety_manager", "pm", "division_manager", "admin",
}

// RegisterTrainingRoutes wires up all training-related endpoints on the
// authenticated api mux. Safety Coordinator+ can view; write roles can create
// and complete.
func RegisterTrainingRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("POST /api/training", middleware.RequireRole(CreateTraining(db), trainingWriteRoles...))
	api.HandleFunc("GET /api/training", middleware.RequireRole(ListTraining(db), trainingReadRoles...))
	api.HandleFunc("GET /api/training/{id}", middleware.RequireRole(GetTraining(db), trainingReadRoles...))
	api.HandleFunc("POST /api/training/{id}/complete", middleware.RequireRole(CompleteTraining(db), trainingWriteRoles...))
}

// ---------- Create ----------

// createTrainingRequest is the JSON body for POST /api/training.
type createTrainingRequest struct {
	CAPAID           uint   `json:"capaId"`
	CourseName       string `json:"courseName"`
	Description      string `json:"description"`
	AssignedToUserID string `json:"assignedToUserId"`
}

// CreateTraining handles POST /api/training.
// Creates a training requirement linked to a Training-category CAPA.
// Due date is copied from the linked CAPA. Audit-logged.
func CreateTraining(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		var req createTrainingRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// Validate required fields.
		if req.CAPAID == 0 {
			http.Error(w, "capaId is required", http.StatusBadRequest)
			return
		}
		if req.CourseName == "" {
			http.Error(w, "courseName is required", http.StatusBadRequest)
			return
		}
		if req.AssignedToUserID == "" {
			http.Error(w, "assignedToUserId is required", http.StatusBadRequest)
			return
		}

		// Verify the CAPA exists and is a Training category.
		var capa models.CAPA
		if err := db.First(&capa, req.CAPAID).Error; err != nil {
			http.Error(w, "CAPA not found", http.StatusNotFound)
			return
		}
		if capa.Category != "Training" {
			http.Error(w, "CAPA must have category 'Training'", http.StatusBadRequest)
			return
		}

		// Prevent duplicate training requirements for the same CAPA.
		var existingCount int64
		db.Model(&models.TrainingRequirement{}).Where("capa_id = ?", req.CAPAID).Count(&existingCount)
		if existingCount > 0 {
			http.Error(w, "training requirement already exists for this CAPA", http.StatusConflict)
			return
		}

		training := models.TrainingRequirement{
			CAPAID:           req.CAPAID,
			CourseName:       req.CourseName,
			Description:      req.Description,
			AssignedToUserID: req.AssignedToUserID,
			AssignedByUserID: userID,
			DueDate:          capa.DueDate,
			Status:           "Pending",
		}

		if err := db.Create(&training).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "create", "training_requirement", training.ID, "", toJSON(training),
			fmt.Sprintf("Training requirement created for CAPA %d", req.CAPAID))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(training)
	}
}

// ---------- List ----------

// ListTraining handles GET /api/training with optional filters.
// Supports: ?status=, ?assigned_to=, ?capa_id=
func ListTraining(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		query := db.Model(&models.TrainingRequirement{})

		// Optional filters.
		if status := r.URL.Query().Get("status"); status != "" {
			query = query.Where("status = ?", status)
		}
		if assignedTo := r.URL.Query().Get("assigned_to"); assignedTo != "" {
			query = query.Where("assigned_to_user_id = ?", assignedTo)
		}
		if capaID := r.URL.Query().Get("capa_id"); capaID != "" {
			query = query.Where("capa_id = ?", capaID)
		}

		// Pagination.
		page := 1
		perPage := 50
		if p := r.URL.Query().Get("page"); p != "" {
			if v, err := strconv.Atoi(p); err == nil && v > 0 {
				page = v
			}
		}
		if pp := r.URL.Query().Get("per_page"); pp != "" {
			if v, err := strconv.Atoi(pp); err == nil && v > 0 && v <= 100 {
				perPage = v
			}
		}

		var total int64
		query.Count(&total)

		var trainings []models.TrainingRequirement
		query.Order("created_at desc").
			Offset((page - 1) * perPage).
			Limit(perPage).
			Find(&trainings)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"data":     trainings,
			"total":    total,
			"page":     page,
			"per_page": perPage,
		})
	}
}

// ---------- Get ----------

// trainingDetailResponse is the JSON response for GET /api/training/{id}.
// It includes the training requirement and its completion record (if any).
type trainingDetailResponse struct {
	Training   models.TrainingRequirement `json:"training"`
	Completion *models.TrainingCompletion `json:"completion"`
}

// GetTraining handles GET /api/training/{id}.
// Returns the training requirement with its completion record (if any).
func GetTraining(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := r.PathValue("id")

		var training models.TrainingRequirement
		if err := db.First(&training, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		// Load completion record if it exists.
		var completion models.TrainingCompletion
		var completionPtr *models.TrainingCompletion
		if err := db.Where("training_requirement_id = ?", training.ID).First(&completion).Error; err == nil {
			completionPtr = &completion
		}

		resp := trainingDetailResponse{
			Training:   training,
			Completion: completionPtr,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// ---------- Complete ----------

// completeTrainingRequest is the JSON body for POST /api/training/{id}/complete.
type completeTrainingRequest struct {
	CompletionDate string  `json:"completionDate"` // RFC3339 or date string
	DurationHours  float64 `json:"durationHours"`
	InstructorName string  `json:"instructorName"`
	Notes          string  `json:"notes"`
	Evidence       string  `json:"evidence"`
}

// CompleteTraining handles POST /api/training/{id}/complete.
// Creates a TrainingCompletion record, sets the training status to Completed,
// and auto-completes the linked CAPA with training completion as evidence.
// Audit-logged.
func CompleteTraining(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		if middleware.IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}

		id := r.PathValue("id")
		var training models.TrainingRequirement
		if err := db.First(&training, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		if training.Status == "Completed" {
			http.Error(w, "training already completed", http.StatusBadRequest)
			return
		}

		var req completeTrainingRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// Parse completion date.
		completionDate, err := time.Parse(time.RFC3339, req.CompletionDate)
		if err != nil {
			// Try date-only format.
			completionDate, err = time.Parse("2006-01-02", req.CompletionDate)
			if err != nil {
				http.Error(w, "invalid completionDate format (use RFC3339 or YYYY-MM-DD)", http.StatusBadRequest)
				return
			}
		}

		// Check for existing completion (idempotency guard).
		var existingCount int64
		db.Model(&models.TrainingCompletion{}).Where("training_requirement_id = ?", training.ID).Count(&existingCount)
		if existingCount > 0 {
			http.Error(w, "completion record already exists", http.StatusConflict)
			return
		}

		beforeJSON := toJSON(training)

		// Create the completion record.
		completion := models.TrainingCompletion{
			TrainingRequirementID: training.ID,
			CompletedByUserID:     userID,
			CompletionDate:        completionDate,
			DurationHours:         req.DurationHours,
			InstructorName:        req.InstructorName,
			Notes:                 req.Notes,
			Evidence:              req.Evidence,
			VerifiedByUserID:      userID,
		}

		// Capture CAPA state before the transaction for audit logging.
		var capa models.CAPA
		var capaBeforeJSON string
		var capaVerificationDue time.Time
		capaUpdated := false

		// Wrap all 3 writes in a single transaction so a partial failure
		// cannot leave the database in an inconsistent state.
		err = db.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&completion).Error; err != nil {
				return err
			}

			// Update training status to Completed.
			training.Status = "Completed"
			if err := tx.Save(&training).Error; err != nil {
				return err
			}

			// Auto-complete the linked CAPA with training evidence.
			if err := tx.First(&capa, training.CAPAID).Error; err == nil {
				if capa.Status == "Open" || capa.Status == "In Progress" {
					capaBeforeJSON = toJSON(capa)

					now := time.Now()
					capaVerificationDue = now.AddDate(0, 0, capaVerificationDueDays(capa.Priority))

					capa.Status = "Verification Pending"
					capa.CompletionNotes = fmt.Sprintf("Training '%s' completed by %s", training.CourseName, userID)
					capa.CompletionEvidence = fmt.Sprintf("Training completion record #%d: %s", completion.ID, req.Evidence)
					capa.CompletionDate = &now
					capa.VerificationDueDate = &capaVerificationDue

					if err := tx.Save(&capa).Error; err != nil {
						return err
					}
					capaUpdated = true
				}
			}

			return nil
		})
		if err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Audit log calls are non-critical and run after the transaction succeeds.
		LogAction(db, userID, userRole, "status_change", "training_requirement", training.ID,
			beforeJSON, toJSON(training),
			fmt.Sprintf("Training completed by %s, duration %.1fh", userID, req.DurationHours))

		if capaUpdated {
			LogAction(db, userID, userRole, "status_change", "capa", capa.ID,
				capaBeforeJSON, toJSON(capa),
				fmt.Sprintf("CAPA auto-completed via training completion #%d, verification due %s",
					completion.ID, capaVerificationDue.Format("2006-01-02")))
		}

		resp := trainingDetailResponse{
			Training:   training,
			Completion: &completion,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
