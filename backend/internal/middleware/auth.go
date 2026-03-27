package middleware

import (
	"net/http"
	"strings"
)

// FirebaseAuth verifies the Firebase JWT token from the Authorization header.
// TODO: Integrate Firebase Admin SDK for real JWT verification.
// For now, this checks that a Bearer token is present.
func FirebaseAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		// TODO: Verify JWT with Firebase Admin SDK
		// token := strings.TrimPrefix(authHeader, "Bearer ")
		// Verify token...

		next.ServeHTTP(w, r)
	})
}
