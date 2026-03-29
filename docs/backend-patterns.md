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

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

func CreateIncident(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Get authenticated user from request context (set by auth middleware)
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)

		var incident models.Incident
		if err := json.NewDecoder(r.Body).Decode(&incident); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if err := db.Create(&incident).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		// Log the action for audit trail — always use context-derived identity, never client-supplied
		LogAction(db, userID, userRole, "create", "incident", incident.ID, "", toJSON(incident), "")

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

Add routes in `backend/cmd/server/main.go`. Public routes go on `mux`, authenticated routes go on `api` (wrapped with `middleware` auth).

```go
// Public
mux.HandleFunc("GET /health", handlers.Health)

// Authenticated (behind auth middleware)
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
role := GetUserRole(r) // reads from request context, set by auth middleware
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

---

## GORM Relationships & Preloading

Define one-to-many relationships using GORM struct tags. The child model must have a foreign key field, and the parent model declares the slice with a `foreignKey` tag.

```go
type Incident struct {
	ID              uint             `gorm:"primaryKey" json:"id"`
	// ... other fields ...
	InjuredPersons  []InjuredPerson  `gorm:"foreignKey:IncidentID" json:"injuredPersons,omitempty"`
	Photos          []IncidentPhoto  `gorm:"foreignKey:IncidentID" json:"photos,omitempty"`
}

type InjuredPerson struct {
	ID         uint   `gorm:"primaryKey" json:"id"`
	IncidentID uint   `gorm:"not null;index" json:"incidentId"`
	Name       string `gorm:"not null" json:"name"`
	// ... other fields ...
}
```

For models with many relationships, list them all in the struct:

```go
type Investigation struct {
	ID                  uint                 `gorm:"primaryKey" json:"id"`
	IncidentID          uint                 `gorm:"not null;uniqueIndex" json:"incidentId"`
	// ... other fields ...
	FiveWhys            []FiveWhy            `gorm:"foreignKey:InvestigationID" json:"fiveWhys,omitempty"`
	ContributingFactors []ContributingFactor `gorm:"foreignKey:InvestigationID" json:"contributingFactors,omitempty"`
	WitnessStatements   []WitnessStatement   `gorm:"foreignKey:InvestigationID" json:"witnessStatements,omitempty"`
}
```

**Loading related records with Preload:**

```go
func GetIncident(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := r.PathValue("id")
		var incident models.Incident
		if err := db.Preload("InjuredPersons").Preload("Photos").First(&incident, id).Error; err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(incident)
	}
}
```

Chain as many `.Preload()` calls as needed. Each one issues a separate SQL query.

**Note:** The order of model registration in `AllModels()` does not matter for Preload to work correctly. However, foreign key constraints are created in registration order during auto-migration, so if you need a specific creation order for constraint reasons, arrange `AllModels()` accordingly (parent models before children).

---

## Auth Context (NOT Headers)

**Do not read user identity from request headers.** Headers can be spoofed by the client. Instead, the auth middleware verifies the JWT and sets the role and user ID on the request context, which is controlled server-side.

**Middleware sets context values:**

```go
// In middleware (after JWT verification)
ctx := context.WithValue(r.Context(), "userRole", role)
ctx = context.WithValue(ctx, "userID", uid)
r = r.WithContext(ctx)
```

**Helper functions to read from context:**

```go
func GetUserRole(r *http.Request) string {
	if role, ok := r.Context().Value("userRole").(string); ok {
		return role
	}
	return ""
}

func GetUserID(r *http.Request) string {
	if uid, ok := r.Context().Value("userID").(string); ok {
		return uid
	}
	return ""
}
```

**Handlers always use the helpers:**

```go
role := GetUserRole(r)
userID := GetUserID(r)
```

Never call `r.Header.Get("X-User-Role")` or similar. The context is the single source of truth for authenticated user identity.

---

## Route Registration Helpers (Recommended)

Each handler file can export a registration function that wires up all routes for its domain. This keeps `main.go` clean.

```go
// In handlers/incidents.go
func RegisterIncidentRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("POST /api/incidents", CreateIncident(db))
	api.HandleFunc("GET /api/incidents", ListIncidents(db))
	api.HandleFunc("GET /api/incidents/{id}", GetIncident(db))
	api.HandleFunc("PUT /api/incidents/{id}", UpdateIncident(db))
}
```

Then in `main.go`:

```go
handlers.RegisterIncidentRoutes(api, db)
handlers.RegisterInvestigationRoutes(api, db)
handlers.RegisterNoteRoutes(api, db)
// one line per domain
```

This is **recommended** but not required. You can still register routes directly in `main.go` if the project is small.

---

## Splitting Large Handler Files

If a handler file exceeds **300 lines**, split it into focused files within the same package. Each file should cover a distinct area of responsibility.

Example for incidents:

- `incidents.go` -- CRUD operations (Create, Read, Update, Delete, List)
- `incidents_osha.go` -- OSHA decision tree logic and recordability checks
- `incidents_railroad.go` -- Railroad-specific deadline checking and FRA rules

All files stay in `package handlers` so they share types and helpers. Keep the split along business logic boundaries, not arbitrary line counts.

---

## Completion Percentage Pattern

Use an explicit field list to calculate how complete a form/record is. This makes it clear exactly which fields are counted and is easy to update.

```go
func CalculateCompletion(inc *Incident) int {
	fields := []bool{
		inc.Type != "",
		!inc.Date.IsZero(),
		inc.Location != "",
		inc.Description != "",
		inc.Severity != "",
		inc.Division != "",
		inc.ReporterID != "",
		// ... all user-editable fields
	}
	filled := 0
	for _, f := range fields {
		if f {
			filled++
		}
	}
	return (filled * 100) / len(fields)
}
```

**Important:** When adding new fields to the Incident model, also add them to this calculation. Auto-generated fields (`ID`, `CreatedAt`, `UpdatedAt`, `Status`, `CompletionPercent`) are **NOT** counted -- only user-editable fields belong in the list.

---

## Business Day Calculator

Use a simple weekend-skipping helper for investigation deadlines (e.g., "5 business days to begin investigation").

```go
func AddBusinessDays(start time.Time, days int) time.Time {
	current := start
	added := 0
	for added < days {
		current = current.AddDate(0, 0, 1)
		if current.Weekday() != time.Saturday && current.Weekday() != time.Sunday {
			added++
		}
	}
	return current
}
```

This skips weekends only. If you need to account for company holidays, add a holiday list check inside the loop.
