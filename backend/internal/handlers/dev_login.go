package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// devLoginRequest is the JSON body accepted by POST /api/dev-login.
type devLoginRequest struct {
	Role        string `json:"role"`
	DisplayName string `json:"displayName"`
}

// devLoginResponse is the JSON body returned by POST /api/dev-login.
type devLoginResponse struct {
	Token       string `json:"token"`
	UserID      string `json:"userId"`
	Role        string `json:"role"`
	DisplayName string `json:"displayName"`
}

// devSecret returns the HS256 signing secret for dev JWTs.
// Mirrors the logic in middleware/auth.go so that tokens round-trip correctly.
func devSecret() []byte {
	if secret := os.Getenv("DEV_JWT_SECRET"); secret != "" {
		return []byte(secret)
	}
	return []byte("highlander-dev-secret")
}

// DevLogin returns an http.HandlerFunc that issues a self-signed HS256 JWT for
// demo / development use.  Register this as a PUBLIC route — it must NOT be
// placed behind the FirebaseAuth middleware.
//
//	POST /api/dev-login
//	Body: {"role":"field_reporter","displayName":"Demo User"}
func DevLogin() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req devLoginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Role == "" {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if req.DisplayName == "" {
			req.DisplayName = "Demo User"
		}

		userID := fmt.Sprintf("dev-%s", req.Role)

		claims := jwt.MapClaims{
			"sub":         userID,
			"role":        req.Role,
			"displayName": req.DisplayName,
			"exp":         time.Now().Add(24 * time.Hour).Unix(),
			"iat":         time.Now().Unix(),
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		signed, err := token.SignedString(devSecret())
		if err != nil {
			http.Error(w, "failed to sign token", http.StatusInternalServerError)
			return
		}

		resp := devLoginResponse{
			Token:       signed,
			UserID:      userID,
			Role:        req.Role,
			DisplayName: req.DisplayName,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
