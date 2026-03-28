package middleware

import (
	"net/http"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/models"
)

// UpdateAgentLastUsed is a middleware that updates AgentApiKey.LastUsedAt on
// every authenticated API call when the request was made by an agent JWT that
// carries a valid key_id claim.
//
// Edge case (TASK-049): LastUsedAt must update on every API call, not just
// at /api/agent/auth time, so the 5-minute active-session heuristic stays
// accurate even for long-lived tokens.
//
// The update is fire-and-forget (goroutine) to keep hot-path latency low.
// A lost update (race on concurrent requests from the same key) is acceptable
// because LastUsedAt is only a display heuristic, not a security mechanism.
func UpdateAgentLastUsed(db *gorm.DB) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Only applies to agent sessions with a known key ID.
			if GetIsAgent(r) {
				if keyID := GetAgentKeyID(r); keyID != 0 {
					now := time.Now()
					go db.Model(&models.AgentApiKey{}).
						Where("id = ? AND is_active = ?", keyID, true).
						Update("last_used_at", now)
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}
