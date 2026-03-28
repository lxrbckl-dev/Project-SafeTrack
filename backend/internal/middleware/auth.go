package middleware

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

// devJWTSecret returns the HS256 signing secret for dev-mode JWTs.
// Override via DEV_JWT_SECRET env var; falls back to a known dev default.
func devJWTSecret() []byte {
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
		token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
			}
			return devJWTSecret(), nil
		})
		if err != nil || !token.Valid {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		userID, _ := claims["sub"].(string)
		userRole, _ := claims["role"].(string)
		userDivision, _ := claims["division"].(string)
		userProject, _ := claims["project"].(string)

		ctx := r.Context()
		ctx = context.WithValue(ctx, "userRole", userRole)
		ctx = context.WithValue(ctx, "userID", userID)
		ctx = context.WithValue(ctx, "userDivision", userDivision)
		ctx = context.WithValue(ctx, "userProject", userProject)
		r = r.WithContext(ctx)

		next.ServeHTTP(w, r)
	})
}
