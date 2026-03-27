package middleware

import (
	"context"
	"net/http"
	"strings"
)

// FirebaseAuth verifies the JWT token from the Authorization header,
// extracts user identity, and sets it on the request context.
//
// TASK-001 will replace this stub with real JWT verification:
// - Dev mode: decode self-signed HS256 JWT from /api/dev-login
// - Prod mode: verify Firebase/Azure AD RS256 JWT against public keys
func FirebaseAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		// TODO (TASK-001): Replace this stub with real JWT decoding.
		// For now, pass through with empty context values.
		// After TASK-001, this will decode the JWT and extract:
		//   - userID from "sub" claim
		//   - userRole from "role" claim
		token := strings.TrimPrefix(authHeader, "Bearer ")
		_ = token // TASK-001: decode this JWT

		// Set user identity on request context (handlers read via GetUserRole/GetUserID)
		ctx := r.Context()
		ctx = context.WithValue(ctx, "userRole", "") // TASK-001: extract from JWT claims
		ctx = context.WithValue(ctx, "userID", "")   // TASK-001: extract from JWT claims
		r = r.WithContext(ctx)

		next.ServeHTTP(w, r)
	})
}
