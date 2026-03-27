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
