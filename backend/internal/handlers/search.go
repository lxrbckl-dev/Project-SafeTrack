package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// SearchResult represents a single unified search result across entity types.
type SearchResult struct {
	EntityType string `json:"entityType"` // incident, investigation, capa
	EntityID   uint   `json:"entityId"`
	Title      string `json:"title"`
	Snippet    string `json:"snippet"`
	Relevance  int    `json:"relevance"` // higher = more relevant
}

// RegisterSearchRoutes wires up the search endpoint on the authenticated api mux.
func RegisterSearchRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("GET /api/search", Search(db))
}

// Search performs a cross-entity text search across incidents, investigations,
// and CAPAs. Results are RBAC-scoped using the same filters as list endpoints.
// Returns up to 20 results sorted by relevance (exact match > partial match).
func Search(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := strings.TrimSpace(r.URL.Query().Get("q"))
		if q == "" {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode([]SearchResult{})
			return
		}

		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		userProject := middleware.GetUserProject(r)
		userDivision := middleware.GetUserDivision(r)

		qLower := strings.ToLower(q)
		pattern := "%" + q + "%"

		var results []SearchResult

		// ---- Search Incidents ----
		results = append(results, searchIncidents(db, pattern, qLower, userID, userRole, userProject, userDivision)...)

		// ---- Search Investigations ----
		results = append(results, searchInvestigations(db, pattern, qLower, userID, userRole, userProject, userDivision)...)

		// ---- Search CAPAs ----
		results = append(results, searchCAPAs(db, pattern, qLower, userID, userRole, userProject, userDivision)...)

		// Sort by relevance descending (exact match > partial).
		sortSearchResults(results)

		// Limit to 20 results.
		if len(results) > 20 {
			results = results[:20]
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(results)
	}
}

// searchIncidents searches incident description, location, and type fields.
// Applies RBAC scoping: drafts only visible to reporter, PM scoped by project,
// Division Manager scoped by division.
func searchIncidents(db *gorm.DB, pattern, qLower, userID, userRole, userProject, userDivision string) []SearchResult {
	query := db.Model(&models.Incident{})

	// Draft visibility: only reporter sees their drafts.
	query = query.Where("(is_draft = false OR reporter_id = ?)", userID)

	// PM scoping.
	if userRole == "pm" && userProject != "" {
		query = query.Where("project_job_site = ?", userProject)
	}

	// Division Manager scoping.
	if userRole == "division_manager" && userDivision != "" {
		query = query.Where("division = ?", userDivision)
	}

	// Text search across description, location, type.
	query = query.Where(
		"description ILIKE ? OR location ILIKE ? OR type ILIKE ?",
		pattern, pattern, pattern,
	)

	var incidents []models.Incident
	query.Limit(20).Find(&incidents)

	results := make([]SearchResult, 0, len(incidents))
	for _, inc := range incidents {
		title := inc.Type + " Incident #" + uintToStr(inc.ID)
		snippet := truncateSnippet(inc.Description, 120)
		relevance := calculateRelevance(qLower, inc.Description, inc.Location, inc.Type)
		results = append(results, SearchResult{
			EntityType: "incident",
			EntityID:   inc.ID,
			Title:      title,
			Snippet:    snippet,
			Relevance:  relevance,
		})
	}
	return results
}

// searchInvestigations searches investigation review comments.
// RBAC: inherits incident visibility rules via join.
func searchInvestigations(db *gorm.DB, pattern, qLower, userID, userRole, userProject, userDivision string) []SearchResult {
	query := db.Model(&models.Investigation{})

	// Join to incident for RBAC scoping — investigations inherit incident visibility.
	query = query.Joins("JOIN incidents ON incidents.id = investigations.incident_id")

	// Draft visibility: only reporter sees their drafts.
	query = query.Where("(incidents.is_draft = false OR incidents.reporter_id = ?)", userID)

	// PM scoping.
	if userRole == "pm" && userProject != "" {
		query = query.Where("incidents.project_job_site = ?", userProject)
	}

	// Division Manager scoping.
	if userRole == "division_manager" && userDivision != "" {
		query = query.Where("incidents.division = ?", userDivision)
	}

	// Text search on review comments.
	query = query.Where("investigations.review_comments ILIKE ?", pattern)

	var investigations []models.Investigation
	query.Limit(20).Find(&investigations)

	results := make([]SearchResult, 0, len(investigations))
	for _, inv := range investigations {
		title := "Investigation #" + uintToStr(inv.ID) + " (Incident #" + uintToStr(inv.IncidentID) + ")"
		snippet := truncateSnippet(inv.ReviewComments, 120)
		relevance := calculateRelevance(qLower, inv.ReviewComments)
		results = append(results, SearchResult{
			EntityType: "investigation",
			EntityID:   inv.ID,
			Title:      title,
			Snippet:    snippet,
			Relevance:  relevance,
		})
	}
	return results
}

// searchCAPAs searches CAPA description and category fields.
// RBAC: inherits incident visibility rules via join through investigation.
func searchCAPAs(db *gorm.DB, pattern, qLower, userID, userRole, userProject, userDivision string) []SearchResult {
	query := db.Model(&models.CAPA{})

	// Join to incident for RBAC scoping — CAPAs link to investigations which link to incidents.
	query = query.Joins("JOIN incidents ON incidents.id = capas.incident_id")

	// Draft visibility: only reporter sees their drafts.
	query = query.Where("(incidents.is_draft = false OR incidents.reporter_id = ?)", userID)

	// PM scoping.
	if userRole == "pm" && userProject != "" {
		query = query.Where("incidents.project_job_site = ?", userProject)
	}

	// Division Manager scoping.
	if userRole == "division_manager" && userDivision != "" {
		query = query.Where("incidents.division = ?", userDivision)
	}

	// Text search on description and category.
	query = query.Where(
		"capas.description ILIKE ? OR capas.category ILIKE ?",
		pattern, pattern,
	)

	var capas []models.CAPA
	query.Limit(20).Find(&capas)

	results := make([]SearchResult, 0, len(capas))
	for _, c := range capas {
		title := c.Category + " CAPA #" + uintToStr(c.ID)
		snippet := truncateSnippet(c.Description, 120)
		relevance := calculateRelevance(qLower, c.Description, c.Category)
		results = append(results, SearchResult{
			EntityType: "capa",
			EntityID:   c.ID,
			Title:      title,
			Snippet:    snippet,
			Relevance:  relevance,
		})
	}
	return results
}

// calculateRelevance scores a search result based on match quality.
// Exact case-insensitive match in any field = 100, partial = 50.
func calculateRelevance(qLower string, fields ...string) int {
	relevance := 0
	for _, field := range fields {
		fieldLower := strings.ToLower(field)
		if fieldLower == qLower {
			// Exact match on the entire field.
			relevance += 100
		} else if strings.Contains(fieldLower, qLower) {
			// Partial match.
			relevance += 50
		}
	}
	return relevance
}

// truncateSnippet shortens a string to maxLen characters, appending "..." if truncated.
func truncateSnippet(s string, maxLen int) string {
	s = strings.TrimSpace(s)
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// uintToStr converts a uint to its string representation.
func uintToStr(n uint) string {
	return strconv.FormatUint(uint64(n), 10)
}

// sortSearchResults sorts results by relevance descending (stable sort preserves
// insertion order for equal relevance).
func sortSearchResults(results []SearchResult) {
	// Simple insertion sort — at most 60 items (20 per entity type).
	for i := 1; i < len(results); i++ {
		key := results[i]
		j := i - 1
		for j >= 0 && results[j].Relevance < key.Relevance {
			results[j+1] = results[j]
			j--
		}
		results[j+1] = key
	}
}
