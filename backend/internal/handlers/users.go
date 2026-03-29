package handlers

import (
	"encoding/json"
	"net/http"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// userResponse is the JSON shape returned by GET /api/users.
// It intentionally omits sensitive fields (password hash, email).
type userResponse struct {
	ID          uint   `json:"id"`
	DisplayName string `json:"displayName"`
	Role        string `json:"role"`
	Division    string `json:"division"`
}

// RegisterUserRoutes wires up user-related endpoints on the authenticated
// api mux. RBAC: Safety Coordinator and above.
func RegisterUserRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("GET /api/users", middleware.RequireRole(
		ListUsers(db),
		"safety_coordinator", "safety_manager", "admin",
	))
}

// ListUsers returns all users as [{id, displayName, role, division}].
//
//	GET /api/users
func ListUsers(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var users []models.User
		if err := db.Order("display_name ASC").Find(&users).Error; err != nil {
			http.Error(w, "failed to query users", http.StatusInternalServerError)
			return
		}

		resp := make([]userResponse, len(users))
		for i, u := range users {
			resp[i] = userResponse{
				ID:          u.ID,
				DisplayName: u.DisplayName,
				Role:        u.Role,
				Division:    u.Division,
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
