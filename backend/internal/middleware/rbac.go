package middleware

import (
	"net/http"
)

// roleHierarchy maps role strings to a numeric access level.
// Higher value = more access.
var roleHierarchy = map[string]int{
	"field_reporter":     0,
	"safety_coordinator": 1,
	"safety_manager":     2,
	"pm":                 3,
	"division_manager":   4,
	"executive":          5,
	"admin":              6,
}

// RoleLevel returns the numeric hierarchy level for a given role string.
// Returns -1 for unknown roles.
func RoleLevel(role string) int {
	if level, ok := roleHierarchy[role]; ok {
		return level
	}
	return -1
}

// RequireRole returns 403 if the user's role is not in the allowed list.
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

// RequireMinRole returns 403 if the user's role level is below the minimum.
// Roles are ordered: field_reporter < safety_coordinator < safety_manager <
// pm < division_manager < executive < admin.
func RequireMinRole(handler http.HandlerFunc, minRole string) http.HandlerFunc {
	minLevel := RoleLevel(minRole)
	return func(w http.ResponseWriter, r *http.Request) {
		userRole := GetUserRole(r)
		if RoleLevel(userRole) < minLevel {
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
