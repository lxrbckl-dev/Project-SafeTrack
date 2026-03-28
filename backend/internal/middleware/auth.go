package middleware

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// DevJWTSecret returns the HS256 signing secret for dev-mode JWTs.
// Override via DEV_JWT_SECRET env var; falls back to a known dev default.
// Exported so the WebSocket handler can reuse the same verification logic.
func DevJWTSecret() []byte {
	if secret := os.Getenv("DEV_JWT_SECRET"); secret != "" {
		return []byte(secret)
	}
	return []byte("highlander-dev-secret")
}

// FirebaseAuth verifies the JWT token from the Authorization header,
// extracts user identity, and sets it on the request context.
//
// Dev mode: decode self-signed HS256 JWT issued by /api/login.
// Prod mode (TODO): verify Firebase / Azure AD RS256 JWT against public keys.
func FirebaseAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")

		// TODO (prod): detect token issuer and verify RS256 against Firebase /
		// Azure AD public keys instead of HS256.

		claims := jwt.MapClaims{}
		// TASK-048 edge case 16: add 30s leeway to token validation to
		// handle clock skew between agent and server.
		token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
			}
			return DevJWTSecret(), nil
		}, jwt.WithLeeway(30*time.Second))
		if err != nil || !token.Valid {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		userID, _ := claims["sub"].(string)
		userRole, _ := claims["role"].(string)
		userDivision, _ := claims["division"].(string)
		userProject, _ := claims["project"].(string)

		// Edge case 1 (JWT backward compat): existing JWTs from /api/login
		// won't have "is_agent". The nil→false type assertion handles this
		// gracefully — old tokens default to human (false).
		isAgent, _ := claims["is_agent"].(bool)

		ctx := r.Context()
		ctx = context.WithValue(ctx, "userRole", userRole)
		ctx = context.WithValue(ctx, "userID", userID)
		ctx = context.WithValue(ctx, "userDivision", userDivision)
		ctx = context.WithValue(ctx, "userProject", userProject)
		ctx = context.WithValue(ctx, "isAgent", isAgent)
		r = r.WithContext(ctx)

		next.ServeHTTP(w, r)
	})
}
