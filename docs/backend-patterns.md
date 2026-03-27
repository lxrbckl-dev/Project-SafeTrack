# Backend Patterns

> How to add features to the Go backend. Follow these patterns for consistency.

---

## Adding a GORM Model

Create a file in `backend/internal/models/`. Use struct tags for GORM constraints and JSON serialization.

```go
package models

import "time"

type Incident struct {
	ID                uint      `gorm:"primaryKey" json:"id"`
	Type              string    `gorm:"not null;index" json:"type"`              // Injury, Near Miss, Property Damage, Environmental, Vehicle, Fire, Utility Strike
	Date              time.Time `gorm:"not null" json:"date"`
	Location          string    `gorm:"not null" json:"location"`
	Description       string    `gorm:"not null;type:text" json:"description"`
	Severity          string    `json:"severity"`
	Status            string    `gorm:"not null;default:'Reported';index" json:"status"` // Reported, Under Investigation, Investigation Complete, CAPA Assigned, CAPA In Progress, Closed, Reopened
	ReporterID        string    `gorm:"not null;index" json:"reporterId"`
	Division          string    `gorm:"index" json:"division"`
	IsDraft           bool      `gorm:"default:false" json:"isDraft"`
	CompletionPercent int       `json:"completionPercent"`
	IsOshaRecordable  bool      `json:"isOshaRecordable"`
	IsDart            bool      `json:"isDart"`
	CreatedAt         time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt         time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}
```

**Then register it in `models/models.go`:**
```go
func AllModels() []interface{} {
	return []interface{}{
		&Note{},
		&AuditLog{},
		&Incident{},   // <-- add here
	}
}
```

GORM auto-migrates on startup — no SQL migrations needed.

---

## Adding a Handler

Create a file in `backend/internal/handlers/`. Handlers receive `*gorm.DB` and return `http.HandlerFunc`.

```go
package handlers

import (
	"encoding/json"
	"net/http"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/models"
)

func CreateIncident(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var incident models.Incident
		if err := json.NewDecoder(r.Body).Decode(&incident); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if err := db.Create(&incident).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Log the action for audit trail
		LogAction(db, incident.ReporterID, "field_reporter", "create", "incident", incident.ID, "", toJSON(incident), "")

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(incident)
	}
}

func toJSON(v interface{}) string {
	b, _ := json.Marshal(v)
	return string(b)
}
```

---

## Registering a Route

Add routes in `backend/cmd/server/main.go`. Public routes go on `mux`, authenticated routes go on `api` (wrapped with `middleware.FirebaseAuth`).

```go
// Public
mux.HandleFunc("GET /health", handlers.Health)

// Authenticated (behind FirebaseAuth middleware)
api.HandleFunc("POST /api/incidents", handlers.CreateIncident(db))
api.HandleFunc("GET /api/incidents", handlers.ListIncidents(db))
api.HandleFunc("GET /api/incidents/{id}", handlers.GetIncident(db))
api.HandleFunc("PUT /api/incidents/{id}", handlers.UpdateIncident(db))
```

---

## Medical Data Encryption

Fields containing medical data (injury type, body part, treatment type, return-to-work status) must be encrypted before saving and decrypted after reading.

```go
import "github.com/lxRbckl/highlander/backend/internal/crypto"

// Before saving
incident.InjuryType, _ = crypto.Encrypt(incident.InjuryType)
incident.BodyPart, _ = crypto.Encrypt(incident.BodyPart)

// After reading (only if user role is Safety Coordinator or above)
incident.InjuryType, _ = crypto.Decrypt(incident.InjuryType)
incident.BodyPart, _ = crypto.Decrypt(incident.BodyPart)
```

The encryption key comes from the `ENCRYPTION_KEY` environment variable (32 bytes for AES-256). A dev fallback is built in.

---

## Audit Logging

Every create, update, status change, approval, or rejection must be audit-logged. Use the `LogAction` helper:

```go
handlers.LogAction(db, userID, userRole, "create", "incident", incident.ID, "", toJSON(incident), "")
handlers.LogAction(db, userID, userRole, "status_change", "investigation", inv.ID, toJSON(before), toJSON(after), "Approved by Safety Manager")
```

Parameters: `db, userID, userRole, action, entityType, entityID, beforeJSON, afterJSON, notes`

The audit log is append-only. Records are never updated or deleted.

---

## Error Handling Pattern

```go
// API errors — return HTTP status + message
if err != nil {
	http.Error(w, "descriptive error message", http.StatusBadRequest)
	return
}

// Database errors — 500
if err := db.Create(&record).Error; err != nil {
	http.Error(w, "database error", http.StatusInternalServerError)
	return
}

// Not found
if err := db.First(&record, id).Error; err != nil {
	http.Error(w, "not found", http.StatusNotFound)
	return
}
```

---

## RBAC Enforcement

The auth middleware extracts the JWT and passes it through. Handlers should check the user's role before performing actions:

```go
// Example: only Safety Manager and above can approve investigations
role := r.Header.Get("X-User-Role") // set by auth middleware after JWT verification
if role != "safety_manager" && role != "admin" {
	http.Error(w, "forbidden", http.StatusForbidden)
	return
}
```

---

## URL Path Parameters

Go 1.22+ `http.ServeMux` supports path parameters:

```go
mux.HandleFunc("GET /api/incidents/{id}", func(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	// use id...
})
```
