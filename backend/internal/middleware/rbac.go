package middleware

import (
	"net/http"
)

// RequireRole returns 403 if the user's role is not in the allowed list.
// This is the primary RBAC enforcement mechanism. Always enumerate the
// allowed roles explicitly rather than relying on a linear hierarchy,
// because PM, Division Manager, and Executive are orthogonal to the
// safety chain (field_reporter < safety_coordinator < safety_manager < admin).
func RequireRole(handler http.HandlerFunc, roles ...string) http.HandlerFunc {
	allowed := make(map[string]bool, len(roles))
	for _, r := range roles {
		allowed[r] = true
	}
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := GetUserRole(r)
		if !allowed[userRole] {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		handler.ServeHTTP(w, r)
	}
}

// IsReadOnlyRole returns true for roles that should not be allowed to create,
// update, or delete records (Executive).
func IsReadOnlyRole(role string) bool {
	return role == "executive"
}

// RejectReadOnly returns 403 if the user has a read-only role (Executive).
// Use this as a guard on create/update/delete endpoints.
func RejectReadOnly(handler http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := GetUserRole(r)
		if IsReadOnlyRole(userRole) {
			http.Error(w, "forbidden: read-only role", http.StatusForbidden)
			return
		}
		handler.ServeHTTP(w, r)
	}
}
