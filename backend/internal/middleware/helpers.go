package middleware

import "net/http"

// GetUserRole reads the authenticated user's role from the request context.
// Set by the auth middleware after JWT verification.
func GetUserRole(r *http.Request) string {
	if role, ok := r.Context().Value("userRole").(string); ok {
		return role
	}
	return ""
}

// GetUserID reads the authenticated user's ID from the request context.
// Set by the auth middleware after JWT verification.
func GetUserID(r *http.Request) string {
	if uid, ok := r.Context().Value("userID").(string); ok {
		return uid
	}
	return ""
}

// GetUserDivision reads the authenticated user's division from the request
// context. Set by the auth middleware from the JWT "division" claim.
// Non-empty only for Division Manager users.
func GetUserDivision(r *http.Request) string {
	if div, ok := r.Context().Value("userDivision").(string); ok {
		return div
	}
	return ""
}

// GetUserProject reads the authenticated user's project from the request
// context. Set by the auth middleware from the JWT "project" claim.
// Non-empty only for PM users.
func GetUserProject(r *http.Request) string {
	if proj, ok := r.Context().Value("userProject").(string); ok {
		return proj
	}
	return ""
}

// GetIsAgent reads the is_agent flag from the request context.
// Returns true when the request was made via an agent API key session.
// Defaults to false for human logins and old JWTs that lack the claim.
func GetIsAgent(r *http.Request) bool {
	if isAgent, ok := r.Context().Value("isAgent").(bool); ok {
		return isAgent
	}
	return false
}
