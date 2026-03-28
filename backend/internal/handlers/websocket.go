package handlers

import (
	"fmt"
	"log"
	"net/http"

	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
)

// upgrader configures the WebSocket upgrade. CheckOrigin allows all origins
// in development; in production this should be locked down.
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // allow all origins for dev
	},
}

// WebSocketHandler returns an http.HandlerFunc that upgrades HTTP connections
// to WebSocket. Authentication is performed via the "token" query parameter
// (JWT), since browsers cannot set custom headers on WebSocket upgrades.
//
// Route: GET /api/ws?token=<jwt>
// This is registered as a PUBLIC route (not behind the auth middleware),
// because WebSocket connections authenticate via query param instead of the
// Authorization header.
func WebSocketHandler(hub *Hub) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Authenticate via query param.
		tokenStr := r.URL.Query().Get("token")
		if tokenStr == "" {
			http.Error(w, "unauthorized: missing token", http.StatusUnauthorized)
			return
		}

		userID, role, division, project, err := parseWSToken(tokenStr)
		if err != nil {
			log.Printf("[ws] auth failed: %v", err)
			http.Error(w, "unauthorized: invalid token", http.StatusUnauthorized)
			return
		}

		// Upgrade to WebSocket.
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("[ws] upgrade failed: %v", err)
			return
		}

		client := &Client{
			hub:      hub,
			conn:     conn,
			send:     make(chan []byte, 256),
			UserID:   userID,
			Role:     role,
			Division: division,
			Project:  project,
		}

		hub.register <- client

		// Start read and write pumps in separate goroutines.
		go client.writePump()
		go client.readPump()
	}
}

// parseWSToken verifies an HS256 JWT from the WebSocket query parameter
// and extracts the user claims. Reuses the same signing secret as the
// auth middleware.
func parseWSToken(tokenStr string) (userID, role, division, project string, err error) {
	claims := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return middleware.DevJWTSecret(), nil
	})
	if err != nil || !token.Valid {
		return "", "", "", "", fmt.Errorf("invalid token: %w", err)
	}

	userID, _ = claims["sub"].(string)
	role, _ = claims["role"].(string)
	division, _ = claims["division"].(string)
	project, _ = claims["project"].(string)

	if userID == "" {
		return "", "", "", "", fmt.Errorf("token missing sub claim")
	}

	return userID, role, division, project, nil
}
