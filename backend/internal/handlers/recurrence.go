package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// RegisterRecurrenceRoutes wires up all recurrence-detection endpoints on the
// authenticated api mux.
func RegisterRecurrenceRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("POST /api/incidents/{id}/check-recurrence", CheckRecurrence(db))
	api.HandleFunc("GET /api/incidents/{id}/dismissed-suggestions", GetDismissedSuggestions(db))
	api.HandleFunc("POST /api/incidents/{id}/dismiss-suggestion", DismissSuggestion(db))
}

// ---------- types ----------

// recurrenceMatch is a single suggestion returned by check-recurrence.
type recurrenceMatch struct {
	IncidentID     uint      `json:"incidentId"`
	Type           string    `json:"type"`
	Date           time.Time `json:"date"`
	Location       string    `json:"location"`
	SimilarityType string    `json:"similarityType"` // comma-separated list of matching criteria
	Score          int       `json:"score"`
	Description    string    `json:"description"`
	MatchCriteria  []string  `json:"matchCriteria"` // individual criteria that matched
}

// ---------- handlers ----------

// CheckRecurrence handles POST /api/incidents/{id}/check-recurrence.
// It scans historical incidents across 4 criteria:
//   - Same location (fuzzy match on location string)
//   - Same type (exact match on incident type)
//   - Same root cause (match contributing factors via investigation)
//   - Same equipment (match on description keywords)
//
// Returns ranked list sorted by score descending.
// RBAC: Safety Coordinator+ only.
func CheckRecurrence(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		if !canCheckRecurrence(userRole) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		idStr := r.PathValue("id")
		incidentID, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			http.Error(w, "invalid incident id", http.StatusBadRequest)
			return
		}

		// Load the source incident.
		var source models.Incident
		if err := db.First(&source, incidentID).Error; err != nil {
			http.Error(w, "incident not found", http.StatusNotFound)
			return
		}

		// Read lookback window from admin settings (default 12 months).
		lookbackMonths := 12
		var setting models.Setting
		if err := db.Where("key = ?", "recurrence_lookback_months").First(&setting).Error; err == nil {
			if v, err := strconv.Atoi(setting.Value); err == nil && v > 0 {
				lookbackMonths = v
			}
		}
		cutoff := time.Now().AddDate(0, -lookbackMonths, 0)

		// Get all incidents within the lookback window, excluding the source
		// and drafts.
		var candidates []models.Incident
		db.Where("id != ? AND is_draft = ? AND date >= ?", incidentID, false, cutoff).
			Find(&candidates)

		if len(candidates) == 0 {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode([]recurrenceMatch{})
			return
		}

		// Collect IDs of incidents already linked to the source.
		var existingLinks []models.IncidentLink
		db.Where("incident_id1 = ? OR incident_id2 = ?", incidentID, incidentID).
			Find(&existingLinks)
		linkedIDs := make(map[uint]bool)
		for _, l := range existingLinks {
			linkedIDs[l.IncidentID1] = true
			linkedIDs[l.IncidentID2] = true
		}

		// Collect IDs of dismissed suggestions for this user+incident.
		var dismissed []models.DismissedSuggestion
		db.Where("incident_id = ? AND dismissed_by_user_id = ?", incidentID, userID).
			Find(&dismissed)
		dismissedIDs := make(map[uint]bool)
		for _, d := range dismissed {
			dismissedIDs[d.SuggestedIncidentID] = true
		}

		// Load contributing factors for the source incident via its investigation.
		sourceFactors := loadFactorTypes(db, uint(incidentID))

		// Load contributing factors for all candidate incidents in a single query.
		candidateIDs := make([]uint, 0, len(candidates))
		for _, c := range candidates {
			candidateIDs = append(candidateIDs, c.ID)
		}
		candidateFactorMap := loadFactorTypesForIncidents(db, candidateIDs)

		// Extract equipment keywords from the source description.
		sourceEquipKeywords := extractEquipmentKeywords(source.Description)

		// Score each candidate.
		var matches []recurrenceMatch
		for _, candidate := range candidates {
			// Skip already-linked incidents.
			if linkedIDs[candidate.ID] {
				continue
			}
			// Skip dismissed suggestions.
			if dismissedIDs[candidate.ID] {
				continue
			}

			score := 0
			var criteria []string

			// Criterion 1: Same location (fuzzy).
			if fuzzyLocationMatch(source.Location, candidate.Location) {
				score++
				criteria = append(criteria, "Same Location")
			}

			// Criterion 2: Same type (exact).
			if source.Type == candidate.Type {
				score++
				criteria = append(criteria, "Same Type")
			}

			// Criterion 3: Same root cause (matching contributing factors).
			candidateFactors := candidateFactorMap[candidate.ID]
			if hasOverlappingFactors(sourceFactors, candidateFactors) {
				score++
				criteria = append(criteria, "Same Root Cause")
			}

			// Criterion 4: Same equipment (keyword match on description).
			candidateEquipKeywords := extractEquipmentKeywords(candidate.Description)
			if hasOverlappingKeywords(sourceEquipKeywords, candidateEquipKeywords) {
				score++
				criteria = append(criteria, "Same Equipment")
			}

			if score > 0 {
				matches = append(matches, recurrenceMatch{
					IncidentID:     candidate.ID,
					Type:           candidate.Type,
					Date:           candidate.Date,
					Location:       candidate.Location,
					SimilarityType: strings.Join(criteria, ", "),
					Score:          score,
					Description:    truncate(candidate.Description, 200),
					MatchCriteria:  criteria,
				})
			}
		}

		// Sort descending by score, then by date descending.
		sortMatches(matches)

		LogAction(db, userID, userRole, "check_recurrence", "incident", uint(incidentID),
			"", toJSON(map[string]interface{}{"matchCount": len(matches)}), "")

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(matches)
	}
}

// GetDismissedSuggestions handles GET /api/incidents/{id}/dismissed-suggestions.
// Returns all dismissed suggestions for the given incident by the current user.
func GetDismissedSuggestions(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		if !canCheckRecurrence(userRole) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		idStr := r.PathValue("id")
		incidentID, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			http.Error(w, "invalid incident id", http.StatusBadRequest)
			return
		}

		var dismissed []models.DismissedSuggestion
		db.Where("incident_id = ? AND dismissed_by_user_id = ?", incidentID, userID).
			Find(&dismissed)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(dismissed)
	}
}

// DismissSuggestion handles POST /api/incidents/{id}/dismiss-suggestion.
// Marks a suggested incident as dismissed so it is not shown again.
func DismissSuggestion(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		if !canCheckRecurrence(userRole) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		idStr := r.PathValue("id")
		incidentID, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			http.Error(w, "invalid incident id", http.StatusBadRequest)
			return
		}

		var req struct {
			SuggestedIncidentID uint `json:"suggestedIncidentId"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}
		if req.SuggestedIncidentID == 0 {
			http.Error(w, "suggestedIncidentId is required", http.StatusBadRequest)
			return
		}

		ds := models.DismissedSuggestion{
			IncidentID:          uint(incidentID),
			SuggestedIncidentID: req.SuggestedIncidentID,
			DismissedByUserID:   userID,
		}

		if err := db.Create(&ds).Error; err != nil {
			// Likely a duplicate — treat as success.
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"status": "already_dismissed"})
			return
		}

		LogAction(db, userID, userRole, "dismiss_suggestion", "incident", uint(incidentID),
			"", toJSON(ds), "")

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(ds)
	}
}

// ---------- helpers ----------

// canCheckRecurrence returns true for Safety Coordinator and above.
func canCheckRecurrence(role string) bool {
	switch role {
	case "safety_coordinator", "safety_manager", "pm", "division_manager", "executive", "admin":
		return true
	}
	return false
}

// fuzzyLocationMatch checks if two location strings are similar enough to
// be considered the same location. It normalises both strings and checks
// if one contains the other (case-insensitive), or if they share a significant
// common prefix.
func fuzzyLocationMatch(a, b string) bool {
	if a == "" || b == "" {
		return false
	}
	na := normaliseLocation(a)
	nb := normaliseLocation(b)
	if na == nb {
		return true
	}
	// Check containment (either direction).
	if strings.Contains(na, nb) || strings.Contains(nb, na) {
		return true
	}
	// Check if they share a long common prefix (at least 60% of the shorter string).
	minLen := len(na)
	if len(nb) < minLen {
		minLen = len(nb)
	}
	threshold := minLen * 6 / 10
	if threshold < 4 {
		threshold = 4
	}
	commonPrefix := 0
	for i := 0; i < len(na) && i < len(nb); i++ {
		if na[i] == nb[i] {
			commonPrefix++
		} else {
			break
		}
	}
	return commonPrefix >= threshold
}

// normaliseLocation lowercases a location string and strips extra whitespace
// and common punctuation for fuzzy comparison.
func normaliseLocation(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	s = strings.ReplaceAll(s, ",", " ")
	s = strings.ReplaceAll(s, ".", " ")
	s = strings.ReplaceAll(s, "-", " ")
	// Collapse multiple spaces.
	for strings.Contains(s, "  ") {
		s = strings.ReplaceAll(s, "  ", " ")
	}
	return s
}

// loadFactorTypes returns the set of contributing factor types for an
// incident via its investigation.
func loadFactorTypes(db *gorm.DB, incidentID uint) map[string]bool {
	var inv models.Investigation
	if err := db.Where("incident_id = ?", incidentID).First(&inv).Error; err != nil {
		return nil
	}
	var factors []models.ContributingFactor
	db.Where("investigation_id = ?", inv.ID).Find(&factors)
	result := make(map[string]bool, len(factors))
	for _, f := range factors {
		result[f.FactorType] = true
	}
	return result
}

// loadFactorTypesForIncidents loads contributing factor types for multiple
// incidents at once, returning a map from incident ID to factor type set.
func loadFactorTypesForIncidents(db *gorm.DB, incidentIDs []uint) map[uint]map[string]bool {
	result := make(map[uint]map[string]bool)
	if len(incidentIDs) == 0 {
		return result
	}

	// Find all investigations for these incidents.
	var investigations []models.Investigation
	db.Where("incident_id IN ?", incidentIDs).Find(&investigations)

	if len(investigations) == 0 {
		return result
	}

	invIDToIncidentID := make(map[uint]uint, len(investigations))
	invIDs := make([]uint, 0, len(investigations))
	for _, inv := range investigations {
		invIDToIncidentID[inv.ID] = inv.IncidentID
		invIDs = append(invIDs, inv.ID)
	}

	// Load all contributing factors for these investigations.
	var factors []models.ContributingFactor
	db.Where("investigation_id IN ?", invIDs).Find(&factors)

	for _, f := range factors {
		incID := invIDToIncidentID[f.InvestigationID]
		if result[incID] == nil {
			result[incID] = make(map[string]bool)
		}
		result[incID][f.FactorType] = true
	}

	return result
}

// hasOverlappingFactors returns true if the two factor-type sets share at
// least one common factor type.
func hasOverlappingFactors(a, b map[string]bool) bool {
	if len(a) == 0 || len(b) == 0 {
		return false
	}
	for k := range a {
		if b[k] {
			return true
		}
	}
	return false
}

// equipmentKeywords are common equipment-related terms used to detect
// "same equipment" matches from incident descriptions.
var equipmentKeywords = []string{
	"crane", "excavator", "loader", "bulldozer", "backhoe", "forklift",
	"scaffold", "scaffolding", "ladder", "harness", "drill", "saw",
	"grinder", "welder", "welding", "compressor", "generator", "pump",
	"conveyor", "hoist", "winch", "truck", "trailer", "vehicle",
	"tamper", "ballast", "rail", "tie", "spike", "gauge", "track",
	"signal", "switch", "crossing", "locomotive", "railcar", "gondola",
	"flatcar", "hopper", "tank car", "derrick", "boom", "bucket",
	"auger", "trencher", "paver", "roller", "plate compactor",
	"jackhammer", "concrete mixer", "dump truck", "water truck",
	"aerial lift", "boom lift", "scissor lift", "cherry picker",
	"skid steer", "mini excavator", "pile driver",
}

// extractEquipmentKeywords returns the set of equipment keywords found in
// the given text.
func extractEquipmentKeywords(text string) map[string]bool {
	if text == "" {
		return nil
	}
	lower := strings.ToLower(text)
	result := make(map[string]bool)
	for _, kw := range equipmentKeywords {
		if strings.Contains(lower, kw) {
			result[kw] = true
		}
	}
	return result
}

// hasOverlappingKeywords returns true if the two keyword sets share at
// least one common keyword.
func hasOverlappingKeywords(a, b map[string]bool) bool {
	if len(a) == 0 || len(b) == 0 {
		return false
	}
	for k := range a {
		if b[k] {
			return true
		}
	}
	return false
}

// truncate shortens a string to maxLen characters, appending "..." if truncated.
func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// sortMatches sorts recurrence matches by score descending, then by date descending.
func sortMatches(matches []recurrenceMatch) {
	for i := 0; i < len(matches); i++ {
		for j := i + 1; j < len(matches); j++ {
			swap := false
			if matches[j].Score > matches[i].Score {
				swap = true
			} else if matches[j].Score == matches[i].Score && matches[j].Date.After(matches[i].Date) {
				swap = true
			}
			if swap {
				matches[i], matches[j] = matches[j], matches[i]
			}
		}
	}
}
