package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/models"
)

// loginRequest is the JSON body accepted by POST /api/login.
type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// loginResponse is the JSON body returned by POST /api/login.
type loginResponse struct {
	Token       string `json:"token"`
	UserID      string `json:"userId"`
	Role        string `json:"role"`
	DisplayName string `json:"displayName"`
}

// loginSecret returns the HS256 signing secret for JWTs.
// Mirrors the logic in middleware/auth.go so that tokens round-trip correctly.
func loginSecret() []byte {
	if secret := os.Getenv("DEV_JWT_SECRET"); secret != "" {
		return []byte(secret)
	}
	return []byte("highlander-dev-secret")
}

// Login returns an http.HandlerFunc that authenticates a user by email and
// password, then issues an HS256 JWT.
//
//	POST /api/login
//	Body: {"email": "reporter@safetrack.demo", "password": "demo1234"}
func Login(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req loginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" || req.Password == "" {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		var user models.User
		if err := db.Where("email = ?", req.Email).First(&user).Error; err != nil {
			http.Error(w, "invalid email or password", http.StatusUnauthorized)
			return
		}

		if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
			http.Error(w, "invalid email or password", http.StatusUnauthorized)
			return
		}

		userID := fmt.Sprintf("%d", user.ID)

		claims := jwt.MapClaims{
			"sub":         userID,
			"role":        user.Role,
			"displayName": user.DisplayName,
			"division":    user.Division,
			"project":     user.Project,
			"exp":         time.Now().Add(24 * time.Hour).Unix(),
			"iat":         time.Now().Unix(),
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		signed, err := token.SignedString(loginSecret())
		if err != nil {
			http.Error(w, "failed to sign token", http.StatusInternalServerError)
			return
		}

		resp := loginResponse{
			Token:       signed,
			UserID:      userID,
			Role:        user.Role,
			DisplayName: user.DisplayName,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
