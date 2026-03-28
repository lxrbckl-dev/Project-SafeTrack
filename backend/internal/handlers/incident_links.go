package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// RegisterIncidentLinkRoutes wires up all incident-link endpoints on the
// authenticated api mux.
func RegisterIncidentLinkRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("POST /api/incident-links", CreateIncidentLink(db))
	api.HandleFunc("GET /api/incidents/{id}/links", GetIncidentLinks(db))
	api.HandleFunc("DELETE /api/incident-links/{id}", DeleteIncidentLink(db))
	api.HandleFunc("GET /api/incident-clusters", GetIncidentClusters(db))
}

// ---------- handlers ----------

// CreateIncidentLink handles POST /api/incident-links.
// Safety Coordinator and above only.
func CreateIncidentLink(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		if !canLinkIncidents(userRole) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		var req struct {
			IncidentID1    uint   `json:"incidentId1"`
			IncidentID2    uint   `json:"incidentId2"`
			SimilarityType string `json:"similarityType"`
			Notes          string `json:"notes"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if req.IncidentID1 == 0 || req.IncidentID2 == 0 {
			http.Error(w, "incidentId1 and incidentId2 are required", http.StatusBadRequest)
			return
		}
		if req.IncidentID1 == req.IncidentID2 {
			http.Error(w, "cannot link an incident to itself", http.StatusBadRequest)
			return
		}
		if !isValidSimilarityType(req.SimilarityType) {
			http.Error(w, "invalid similarityType", http.StatusBadRequest)
			return
		}

		// Normalise pair order so (A,B) and (B,A) share the same unique constraint.
		id1, id2 := req.IncidentID1, req.IncidentID2
		if id1 > id2 {
			id1, id2 = id2, id1
		}

		link := models.IncidentLink{
			IncidentID1:    id1,
			IncidentID2:    id2,
			SimilarityType: req.SimilarityType,
			Notes:          req.Notes,
			LinkedByUserID: userID,
		}

		if err := db.Create(&link).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "create", "incident_link", link.ID, "", toJSON(link), "")

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(link)
	}
}

// GetIncidentLinks handles GET /api/incidents/{id}/links.
// Returns all links involving the given incident, enriched with both
// incident summaries for display.
func GetIncidentLinks(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		idStr := r.PathValue("id")
		incidentID, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			http.Error(w, "invalid incident id", http.StatusBadRequest)
			return
		}

		var links []models.IncidentLink
		if err := db.Where(
			"incident_id1 = ? OR incident_id2 = ?", incidentID, incidentID,
		).Find(&links).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Collect all "other" incident IDs for a single batch fetch.
		type LinkedIncidentSummary struct {
			ID       uint   `json:"id"`
			Type     string `json:"type"`
			Location string `json:"location"`
			Status   string `json:"status"`
			Severity string `json:"severity"`
			Division string `json:"division"`
		}
		type LinkWithIncident struct {
			models.IncidentLink
			LinkedIncident LinkedIncidentSummary `json:"linkedIncident"`
		}

		otherIDs := make([]uint, 0, len(links))
		for _, l := range links {
			otherID := l.IncidentID1
			if otherID == uint(incidentID) {
				otherID = l.IncidentID2
			}
			otherIDs = append(otherIDs, otherID)
		}

		var others []models.Incident
		if err := db.Select("id, type, location, status, severity, division").
			Where("id IN ?", otherIDs).Find(&others).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		otherByID := make(map[uint]models.Incident, len(others))
		for _, o := range others {
			otherByID[o.ID] = o
		}

		result := make([]LinkWithIncident, 0, len(links))
		for _, l := range links {
			otherID := l.IncidentID1
			if otherID == uint(incidentID) {
				otherID = l.IncidentID2
			}
			if other, ok := otherByID[otherID]; ok {
				result = append(result, LinkWithIncident{
					IncidentLink: l,
					LinkedIncident: LinkedIncidentSummary{
						ID:       other.ID,
						Type:     other.Type,
						Location: other.Location,
						Status:   other.Status,
						Severity: other.Severity,
						Division: other.Division,
					},
				})
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)
	}
}

// DeleteIncidentLink handles DELETE /api/incident-links/{id}.
// Safety Coordinator and above only.
func DeleteIncidentLink(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		if !canLinkIncidents(userRole) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		idStr := r.PathValue("id")
		linkID, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			http.Error(w, "invalid link id", http.StatusBadRequest)
			return
		}

		var link models.IncidentLink
		if err := db.First(&link, linkID).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		beforeJSON := toJSON(link)

		if err := db.Delete(&link).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, userID, userRole, "delete", "incident_link", link.ID, beforeJSON, "", "")

		w.WriteHeader(http.StatusNoContent)
	}
}

// GetIncidentClusters handles GET /api/incident-clusters.
// Returns incidents grouped by their linked clusters via union-find.
func GetIncidentClusters(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var links []models.IncidentLink
		if err := db.Find(&links).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Collect all incident IDs involved in at least one link.
		idSet := make(map[uint]struct{})
		for _, l := range links {
			idSet[l.IncidentID1] = struct{}{}
			idSet[l.IncidentID2] = struct{}{}
		}
		if len(idSet) == 0 {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode([]interface{}{})
			return
		}

		allIDs := make([]uint, 0, len(idSet))
		for id := range idSet {
			allIDs = append(allIDs, id)
		}

		var incidents []models.Incident
		db.Select("id, type, location, status, severity, division, date").
			Where("id IN ?", allIDs).Find(&incidents)

		incidentByID := make(map[uint]models.Incident, len(incidents))
		for _, inc := range incidents {
			incidentByID[inc.ID] = inc
		}

		// Union-find to cluster connected incidents.
		parent := make(map[uint]uint)
		for _, id := range allIDs {
			parent[id] = id
		}
		var find func(uint) uint
		find = func(x uint) uint {
			if parent[x] != x {
				parent[x] = find(parent[x])
			}
			return parent[x]
		}
		union := func(a, b uint) {
			ra, rb := find(a), find(b)
			if ra != rb {
				parent[rb] = ra
			}
		}
		for _, l := range links {
			union(l.IncidentID1, l.IncidentID2)
		}

		// Group incidents by cluster root.
		clusterMap := make(map[uint][]uint)
		for _, id := range allIDs {
			root := find(id)
			clusterMap[root] = append(clusterMap[root], id)
		}

		// Collect similarity types per cluster for "common threads".
		type commonThread struct {
			SimilarityType string `json:"similarityType"`
			Count          int    `json:"count"`
		}
		type clusterResponse struct {
			ClusterID     uint              `json:"clusterId"`
			Incidents     []models.Incident `json:"incidents"`
			CommonThreads []commonThread    `json:"commonThreads"`
		}

		clusters := make([]clusterResponse, 0, len(clusterMap))
		for root, memberIDs := range clusterMap {
			// Collect incidents for this cluster.
			members := make([]models.Incident, 0, len(memberIDs))
			for _, id := range memberIDs {
				if inc, ok := incidentByID[id]; ok {
					members = append(members, inc)
				}
			}

			// Count similarity types among all links within this cluster.
			simCounts := make(map[string]int)
			for _, l := range links {
				if find(l.IncidentID1) == root {
					simCounts[l.SimilarityType]++
				}
			}
			threads := make([]commonThread, 0, len(simCounts))
			for st, cnt := range simCounts {
				threads = append(threads, commonThread{SimilarityType: st, Count: cnt})
			}

			clusters = append(clusters, clusterResponse{
				ClusterID:     root,
				Incidents:     members,
				CommonThreads: threads,
			})
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(clusters)
	}
}

// ---------- helpers ----------

// canLinkIncidents returns true for Safety Coordinator and above.
func canLinkIncidents(role string) bool {
	switch role {
	case "safety_coordinator", "safety_manager", "admin":
		return true
	}
	return false
}

// isValidSimilarityType validates similarity type values.
func isValidSimilarityType(s string) bool {
	switch s {
	case "Same Location", "Same Type", "Same Root Cause", "Same Equipment", "Same Person":
		return true
	}
	return false
}
