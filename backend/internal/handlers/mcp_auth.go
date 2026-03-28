package handlers

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/models"
)

// ---------- MCP rate limiter (edge case 5: 60 req/min per API key) ----------

// mcpRateLimiter tracks request counts per API key prefix to enforce the
// 60 requests/minute limit. This prevents a single agent from overwhelming
// the system with rapid tool calls.
type mcpRateLimiter struct {
	mu       sync.Mutex
	requests map[string][]time.Time
}

const (
	mcpRateLimitWindow = 1 * time.Minute
	mcpRateLimitMax    = 60
)

var mcpLimiter = &mcpRateLimiter{
	requests: make(map[string][]time.Time),
}

// allow checks whether a request from the given key prefix is within the
// rate limit. Returns true if allowed, false if the limit is exceeded.
func (rl *mcpRateLimiter) allow(keyPrefix string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-mcpRateLimitWindow)

	// Prune old entries.
	recent := make([]time.Time, 0, len(rl.requests[keyPrefix]))
	for _, t := range rl.requests[keyPrefix] {
		if t.After(cutoff) {
			recent = append(recent, t)
		}
	}

	if len(recent) >= mcpRateLimitMax {
		rl.requests[keyPrefix] = recent
		return false
	}

	recent = append(recent, now)
	rl.requests[keyPrefix] = recent
	return true
}

// ---------- MCP Auth middleware ----------

// MCPAuth is an authentication middleware for the /mcp/* route namespace.
// It accepts API keys in the Authorization header (Bearer stk_...) and
// validates them against stored bcrypt hashes. On success it populates
// the request context with user identity fields identical to FirebaseAuth
// so downstream handlers work transparently.
//
// Edge case 1: /mcp/* uses separate MCPAuth (API key), NOT FirebaseAuth.
// Edge case 5: rate limiting — 60 req/min per API key.
// Edge case 16: JWT expiry leeway — not applicable here since we validate
// the API key directly (no JWT in the MCP path).
func MCPAuth(db *gorm.DB) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Edge case 17: request body limit — 1MB for non-upload MCP requests.
			r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB

			authHeader := r.Header.Get("Authorization")
			if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
				writeJSONRPCError(w, nil, -32000, "unauthorized: missing or invalid Authorization header", http.StatusUnauthorized)
				return
			}

			apiKey := strings.TrimPrefix(authHeader, "Bearer ")

			// Validate it looks like an API key (stk_ prefix).
			if !strings.HasPrefix(apiKey, "stk_") {
				writeJSONRPCError(w, nil, -32000, "unauthorized: invalid API key format", http.StatusUnauthorized)
				return
			}

			if len(apiKey) < 8 {
				writeJSONRPCError(w, nil, -32000, "invalid API key format", http.StatusUnauthorized)
				return
			}

			keyPrefix := apiKey[:8]

			// Edge case 5: rate limiting before doing expensive bcrypt.
			if !mcpLimiter.allow(keyPrefix) {
				writeJSONRPCError(w, nil, -32005, "rate limit exceeded: 60 requests per minute", http.StatusTooManyRequests)
				return
			}

			// Find matching active keys by prefix, then verify with bcrypt.
			var candidates []models.AgentApiKey
			db.Where("is_active = ? AND key_prefix = ?", true, keyPrefix).Find(&candidates)
			if len(candidates) == 0 {
				// Fallback: scan all active keys (handles prefix mismatch).
				db.Where("is_active = ?", true).Find(&candidates)
			}

			var matchedKey *models.AgentApiKey
			for i := range candidates {
				if err := bcrypt.CompareHashAndPassword([]byte(candidates[i].KeyHash), []byte(apiKey)); err == nil {
					matchedKey = &candidates[i]
					break
				}
			}

			if matchedKey == nil {
				log.Printf("[mcp-auth] failed auth attempt for key prefix %s", keyPrefix)
				writeJSONRPCError(w, nil, -32000, "unauthorized: invalid API key", http.StatusUnauthorized)
				return
			}

			// Load the associated user for role and identity.
			var user models.User
			if err := db.First(&user, matchedKey.UserID).Error; err != nil {
				writeJSONRPCError(w, nil, -32603, "internal error: user not found for key", http.StatusInternalServerError)
				return
			}

			// Update last-used timestamp.
			now := time.Now()
			matchedKey.LastUsedAt = &now
			db.Save(matchedKey)

			userID := fmt.Sprintf("%d", user.ID)

			// Populate context with the same keys as FirebaseAuth so all
			// downstream handlers (middleware.GetUserRole, etc.) work.
			ctx := r.Context()
			ctx = context.WithValue(ctx, "userRole", user.Role)
			ctx = context.WithValue(ctx, "userID", userID)
			ctx = context.WithValue(ctx, "userDivision", user.Division)
			ctx = context.WithValue(ctx, "userProject", user.Project)
			ctx = context.WithValue(ctx, "isAgent", true)
			ctx = context.WithValue(ctx, "mcpKeyPrefix", keyPrefix)
			r = r.WithContext(ctx)

			next.ServeHTTP(w, r)
		})
	}
}
