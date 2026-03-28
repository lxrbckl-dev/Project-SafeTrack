package middleware

import (
	"net/http"
	"strings"
)

// CORS adds Cross-Origin Resource Sharing headers to all responses.
//
// Edge case 8 (TASK-048): MCP clients like Claude Desktop may send custom
// headers (X-MCP-Version, X-Idempotency-Key) that fail CORS preflight.
// These are included in the Access-Control-Allow-Headers list.
//
// Edge case (security headers): adds X-Content-Type-Options and
// Cache-Control headers for all responses, especially important for
// MCP responses containing sensitive data.
func CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers",
			"Content-Type, Authorization, X-MCP-Version, X-Idempotency-Key, X-Request-ID")
		w.Header().Set("Access-Control-Expose-Headers",
			"X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset")

		// Security headers — prevent MIME sniffing and disable caching for
		// API responses (especially MCP responses containing sensitive data).
		w.Header().Set("X-Content-Type-Options", "nosniff")
		if strings.HasPrefix(r.URL.Path, "/mcp/") || strings.HasPrefix(r.URL.Path, "/api/") {
			w.Header().Set("Cache-Control", "no-store")
		}

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}
