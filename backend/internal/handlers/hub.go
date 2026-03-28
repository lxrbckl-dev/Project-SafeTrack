package handlers

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// ---------- WebSocket event types ----------

// WSEvent is the envelope sent to clients over the WebSocket connection.
// Type is one of "notification" or "activity".
type WSEvent struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

// ---------- Client ----------

const (
	// writeWait is the time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// pongWait is the time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// pingPeriod sends pings at this interval. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// maxMessageSize is the maximum message size allowed from the peer.
	maxMessageSize = 512
)

// Client represents a single WebSocket connection.
type Client struct {
	hub  *Hub
	conn *websocket.Conn
	send chan []byte

	// Identity fields populated from JWT claims.
	UserID   string
	Role     string
	Division string
	Project  string
}

// readPump reads messages from the WebSocket connection. The only purpose is
// to keep the connection alive via pong handling and to detect close.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Printf("[ws] unexpected close: %v", err)
			}
			break
		}
	}
}

// writePump writes messages from the send channel to the WebSocket connection.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Hub closed the channel.
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ---------- Hub ----------

// Hub maintains the set of active clients and broadcasts events to them.
type Hub struct {
	// mu protects the clients map.
	mu sync.RWMutex

	// clients is the set of registered clients.
	clients map[*Client]bool

	// register requests from clients.
	register chan *Client

	// unregister requests from clients.
	unregister chan *Client

	// broadcast channel receives events to send to all relevant clients.
	broadcastCh chan WSEvent
}

// NewHub creates and returns a new Hub instance.
func NewHub() *Hub {
	return &Hub{
		clients:     make(map[*Client]bool),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		broadcastCh: make(chan WSEvent, 256),
	}
}

// Run starts the hub's event loop. Should be launched as a goroutine.
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Printf("[ws] client connected: userID=%s role=%s (%d total)", client.UserID, client.Role, h.clientCount())

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mu.Unlock()
			log.Printf("[ws] client disconnected: userID=%s (%d total)", client.UserID, h.clientCount())

		case event := <-h.broadcastCh:
			h.broadcastToClients(event)
		}
	}
}

// Broadcast sends an event to all connected clients that should receive it
// based on RBAC rules. This is the public API called by handlers.
func (h *Hub) Broadcast(event WSEvent) {
	select {
	case h.broadcastCh <- event:
	default:
		log.Println("[ws] broadcast channel full, dropping event")
	}
}

// broadcastToClients sends an event to all relevant clients.
// RBAC filtering: notification events are routed only to the target user
// (identified by event.Data["userId"]); activity events are visible to all
// connected clients (RBAC scoping is done at the API layer when clients
// fetch full data).
func (h *Hub) broadcastToClients(event WSEvent) {
	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("[ws] failed to marshal event: %v", err)
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for client := range h.clients {
		// Bug 1 fix: Only send notification events to the target user.
		if event.Type == "notification" {
			dataMap, ok := event.Data.(map[string]interface{})
			if ok {
				targetUserID, ok := dataMap["userId"].(string)
				if ok && client.UserID != targetUserID {
					continue // skip this client
				}
			}
		}

		select {
		case client.send <- data:
		default:
			// Bug 2 fix: Client's send buffer is full — schedule disconnect
			// via the unregister channel so Run() handles cleanup under the
			// write lock, avoiding a concurrent map write under RLock.
			go func(c *Client) {
				h.unregister <- c
			}(client)
		}
	}
}

// clientCount returns the number of connected clients (thread-safe).
func (h *Hub) clientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}
