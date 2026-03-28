package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// ---------- Rate limiter for /api/agent/auth (edge case 6) ----------

// rateLimiter tracks failed auth attempts per IP to mitigate brute-force
// attacks. Allows maxAttempts failures per window before blocking.
type rateLimiter struct {
	mu       sync.Mutex
	attempts map[string][]time.Time
}

const (
	rateLimitWindow   = 1 * time.Minute
	rateLimitMaxFails = 5
)

var agentAuthLimiter = &rateLimiter{
	attempts: make(map[string][]time.Time),
}

// recordFailure logs a failed attempt from an IP and returns true if the IP
// is currently blocked (i.e. exceeded the max attempts within the window).
func (rl *rateLimiter) recordFailure(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-rateLimitWindow)

	// Prune old entries.
	recent := make([]time.Time, 0, len(rl.attempts[ip]))
	for _, t := range rl.attempts[ip] {
		if t.After(cutoff) {
			recent = append(recent, t)
		}
	}
	recent = append(recent, now)
	rl.attempts[ip] = recent

	return len(recent) > rateLimitMaxFails
}

// isBlocked returns true if the IP has exceeded the failure threshold
// within the current window (without recording a new attempt).
func (rl *rateLimiter) isBlocked(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	cutoff := time.Now().Add(-rateLimitWindow)
	count := 0
	for _, t := range rl.attempts[ip] {
		if t.After(cutoff) {
			count++
		}
	}
	return count >= rateLimitMaxFails
}

// ---------- Request / response types ----------

type createKeyRequest struct {
	UserID uint   `json:"userId"`
	Name   string `json:"name"`
}

type createKeyResponse struct {
	Key    string `json:"key"`    // full key — shown exactly once
	Prefix string `json:"prefix"` // first 8 chars for future reference
	ID     uint   `json:"id"`
	UserID uint   `json:"userId"`
	Role   string `json:"role"`
	Name   string `json:"name"`
}

type agentAuthRequest struct {
	APIKey string `json:"apiKey"`
}

type agentAuthResponse struct {
	Token       string `json:"token"`
	UserID      string `json:"userId"`
	Role        string `json:"role"`
	DisplayName string `json:"displayName"`
	IsAgent     bool   `json:"isAgent"`
}

type listKeyEntry struct {
	ID         uint       `json:"id"`
	UserID     uint       `json:"userId"`
	KeyPrefix  string     `json:"keyPrefix"`
	Name       string     `json:"name"`
	IsActive   bool       `json:"isActive"`
	LastUsedAt *time.Time `json:"lastUsedAt"`
	CreatedAt  time.Time  `json:"createdAt"`
	RevokedAt  *time.Time `json:"revokedAt"`
}

// ---------- Handlers ----------

// CreateAgentKey handles POST /api/agent/keys.
// RBAC: Safety Manager or Admin only.
// Generates a cryptographically secure random API key, stores a bcrypt hash,
// and returns the full key exactly once.
func CreateAgentKey(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		callerRole := middleware.GetUserRole(r)
		callerID := middleware.GetUserID(r)
		isAgent := middleware.GetIsAgent(r)

		if callerRole != "admin" && callerRole != "safety_manager" {
			http.Error(w, "forbidden: only Admin or Safety Manager can create API keys", http.StatusForbidden)
			return
		}

		var req createKeyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" || req.UserID == 0 {
			http.Error(w, "invalid request: userId and name are required", http.StatusBadRequest)
			return
		}

		// Verify target user exists and get their role.
		var user models.User
		if err := db.First(&user, req.UserID).Error; err != nil {
			http.Error(w, "user not found", http.StatusNotFound)
			return
		}

		// Edge case 4: Generate key using crypto/rand (not math/rand).
		rawKey := make([]byte, 32)
		if _, err := rand.Read(rawKey); err != nil {
			http.Error(w, "failed to generate key", http.StatusInternalServerError)
			return
		}
		fullKey := "stk_" + hex.EncodeToString(rawKey) // 68 chars total
		prefix := fullKey[:8]                          // "stk_" + first 4 hex chars

		// Edge case 9: CRITICAL — use bcrypt for key hashing, never plain SHA256.
		hash, err := bcrypt.GenerateFromPassword([]byte(fullKey), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, "failed to hash key", http.StatusInternalServerError)
			return
		}

		apiKey := models.AgentApiKey{
			UserID:    req.UserID,
			KeyHash:   string(hash),
			KeyPrefix: prefix,
			Name:      req.Name,
			IsActive:  true,
		}

		if err := db.Create(&apiKey).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Audit log — edge case 7: never log the full key.
		LogAction(db, callerID, callerRole, "create", "agent_api_key", apiKey.ID, "",
			fmt.Sprintf(`{"userId":%d,"name":"%s","prefix":"%s"}`, req.UserID, req.Name, prefix),
			fmt.Sprintf("API key created for user %d (%s)", user.ID, user.DisplayName), isAgent)

		// Edge case 5: return full key exactly once.
		resp := createKeyResponse{
			Key:    fullKey,
			Prefix: prefix,
			ID:     apiKey.ID,
			UserID: user.ID,
			Role:   user.Role,
			Name:   req.Name,
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(resp)
	}
}

// ListAgentKeys handles GET /api/agent/keys.
// Returns active keys for the current user (prefix + name + lastUsed, never
// full key). Admin/Safety Manager can see all keys.
func ListAgentKeys(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		callerRole := middleware.GetUserRole(r)
		callerID := middleware.GetUserID(r)

		if callerRole != "admin" && callerRole != "safety_manager" {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		query := db.Model(&models.AgentApiKey{}).Order("created_at desc")

		// Filter by user if requested.
		if uid := r.URL.Query().Get("user_id"); uid != "" {
			query = query.Where("user_id = ?", uid)
		}
		// Filter by active only unless show_revoked is set.
		if r.URL.Query().Get("show_revoked") != "true" {
			query = query.Where("is_active = ?", true)
		}

		var keys []models.AgentApiKey
		if err := query.Find(&keys).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Never return the hash — only expose safe metadata.
		entries := make([]listKeyEntry, len(keys))
		for i, k := range keys {
			entries[i] = listKeyEntry{
				ID:         k.ID,
				UserID:     k.UserID,
				KeyPrefix:  k.KeyPrefix,
				Name:       k.Name,
				IsActive:   k.IsActive,
				LastUsedAt: k.LastUsedAt,
				CreatedAt:  k.CreatedAt,
				RevokedAt:  k.RevokedAt,
			}
		}

		_ = callerID // used for RBAC check above

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(entries)
	}
}

// RevokeAgentKey handles DELETE /api/agent/keys/{id}.
// Sets IsActive=false and RevokedAt=now. Audit-logged.
func RevokeAgentKey(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		callerRole := middleware.GetUserRole(r)
		callerID := middleware.GetUserID(r)
		isAgent := middleware.GetIsAgent(r)

		if callerRole != "admin" && callerRole != "safety_manager" {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		id := r.PathValue("id")
		var apiKey models.AgentApiKey
		if err := db.First(&apiKey, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		if !apiKey.IsActive {
			http.Error(w, "key already revoked", http.StatusConflict)
			return
		}

		now := time.Now()
		apiKey.IsActive = false
		apiKey.RevokedAt = &now

		if err := db.Save(&apiKey).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		LogAction(db, callerID, callerRole, "revoke", "agent_api_key", apiKey.ID, "",
			fmt.Sprintf(`{"userId":%d,"prefix":"%s","revoked":true}`, apiKey.UserID, apiKey.KeyPrefix),
			fmt.Sprintf("API key %s revoked", apiKey.KeyPrefix), isAgent)

		w.WriteHeader(http.StatusNoContent)
	}
}

// AgentAuth handles POST /api/agent/auth.
// This is a PUBLIC route (no JWT required). Agents present an API key and
// receive a JWT with is_agent=true and a short 1-hour expiry (edge case 8).
//
// Rate limiting: tracks failed attempts per IP (edge case 6).
// Key scrubbing: never logs full key material (edge case 7).
func AgentAuth(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Edge case 6: rate limit check before doing any work.
		clientIP := r.RemoteAddr
		if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
			clientIP = forwarded
		}
		if agentAuthLimiter.isBlocked(clientIP) {
			http.Error(w, "too many failed attempts, try again later", http.StatusTooManyRequests)
			return
		}

		var req agentAuthRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.APIKey == "" {
			http.Error(w, "invalid request: apiKey is required", http.StatusBadRequest)
			return
		}

		// Edge case 7: never log the full key. Use only the prefix for logging.
		keyPrefix := req.APIKey
		if len(keyPrefix) > 8 {
			keyPrefix = keyPrefix[:8]
		}

		// Find all active keys and compare against bcrypt hashes.
		// Prefix-based lookup narrows the search to avoid scanning all keys.
		var candidates []models.AgentApiKey
		if len(req.APIKey) >= 8 {
			db.Where("is_active = ? AND key_prefix = ?", true, req.APIKey[:8]).Find(&candidates)
		}
		if len(candidates) == 0 {
			// Fallback: check all active keys (handles edge case where prefix
			// extraction doesn't match, e.g., key format changed).
			db.Where("is_active = ?", true).Find(&candidates)
		}

		var matchedKey *models.AgentApiKey
		for i := range candidates {
			// Edge case 9: use bcrypt.CompareHashAndPassword.
			if err := bcrypt.CompareHashAndPassword([]byte(candidates[i].KeyHash), []byte(req.APIKey)); err == nil {
				matchedKey = &candidates[i]
				break
			}
		}

		if matchedKey == nil {
			agentAuthLimiter.recordFailure(clientIP)
			// Edge case 7: do not reveal whether key exists. Generic error.
			log.Printf("[agent-auth] failed attempt from %s for key prefix %s", clientIP, keyPrefix)
			http.Error(w, "invalid API key", http.StatusUnauthorized)
			return
		}

		// Load the associated user to get role and claims.
		var user models.User
		if err := db.First(&user, matchedKey.UserID).Error; err != nil {
			http.Error(w, "user not found for key", http.StatusInternalServerError)
			return
		}

		// Update last used timestamp.
		now := time.Now()
		matchedKey.LastUsedAt = &now
		db.Save(matchedKey)

		userID := fmt.Sprintf("%d", user.ID)

		// Edge case 8: agent JWT expiry = 1 hour (not 24h like human sessions).
		claims := jwt.MapClaims{
			"sub":         userID,
			"role":        user.Role,
			"displayName": user.DisplayName,
			"division":    user.Division,
			"project":     user.Project,
			"is_agent":    true, // edge case 1: agents always get this claim
			"exp":         time.Now().Add(1 * time.Hour).Unix(),
			"iat":         time.Now().Unix(),
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		signed, err := token.SignedString(middleware.DevJWTSecret())
		if err != nil {
			http.Error(w, "failed to sign token", http.StatusInternalServerError)
			return
		}

		// Audit log the agent login (without key material).
		LogAction(db, userID, user.Role, "agent_login", "agent_api_key", matchedKey.ID, "",
			fmt.Sprintf(`{"prefix":"%s","userId":%d}`, matchedKey.KeyPrefix, user.ID),
			"Agent authenticated via API key", true)

		resp := agentAuthResponse{
			Token:       signed,
			UserID:      userID,
			Role:        user.Role,
			DisplayName: user.DisplayName,
			IsAgent:     true,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// RegisterAgentRoutes wires up agent API key management endpoints.
// Called from main.go to register under the authenticated mux.
func RegisterAgentRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("POST /api/agent/keys", CreateAgentKey(db))
	api.HandleFunc("GET /api/agent/keys", ListAgentKeys(db))
	api.HandleFunc("DELETE /api/agent/keys/{id}", RevokeAgentKey(db))
}
