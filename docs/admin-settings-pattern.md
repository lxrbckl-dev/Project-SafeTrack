# Admin Settings Pattern

> How to build configurable admin settings (factor types, TRIR benchmark, etc.)

---

## Go Model

Store settings as key-value pairs with a category for grouping:

```go
// backend/internal/models/setting.go
package models

import "time"

type Setting struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Category  string    `gorm:"not null;index" json:"category"`  // e.g., "factor_types", "dashboard", "notifications"
	Key       string    `gorm:"not null;uniqueIndex" json:"key"` // e.g., "trir_benchmark", "factor_types_list"
	Value     string    `gorm:"type:text;not null" json:"value"` // JSON string for complex values, plain string for simple ones
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
	UpdatedBy string    `json:"updatedBy"`
}
```

Register in `models/models.go` AllModels().

---

## Go Handlers

```go
// backend/internal/handlers/settings.go

// GET /api/settings — returns all settings (grouped by category)
// GET /api/settings?category=dashboard — returns settings for one category
// PUT /api/settings/{key} — updates a setting (Admin role only)
```

On PUT, audit-log the change with before/after values.

---

## Seed Data

Create default settings on first run. In `database/postgres.go` after AutoMigrate:

```go
// Seed default settings if none exist
var count int64
db.Model(&models.Setting{}).Count(&count)
if count == 0 {
	defaults := []models.Setting{
		{Category: "dashboard", Key: "trir_benchmark", Value: "3.0", UpdatedBy: "system"},
		{Category: "factor_types", Key: "factor_types_list", Value: `["People","Equipment","Environmental","Procedural","Management/Organizational"]`, UpdatedBy: "system"},
		{Category: "notifications", Key: "escalation_days", Value: `[3,7,14]`, UpdatedBy: "system"},
	}
	db.Create(&defaults)
}
```

---

## Flutter Admin Page

```
flutter/lib/features/admin/
  pages/
    admin_settings_page.dart    # Main settings page
    factor_types_page.dart      # CRUD for contributing factor types
  widgets/
    setting_tile.dart           # Reusable setting row (label + value + edit)
```

- Only visible to Admin role (check role in router guard)
- Factor types page: list with add/edit/delete — stores as JSON array in the `factor_types_list` setting
- TRIR benchmark: simple numeric input field
- Every save calls `PUT /api/settings/{key}` and triggers an audit log entry

---

## Route Registration

```go
// In main.go, under authenticated routes:
api.HandleFunc("GET /api/settings", handlers.GetSettings(db))
api.HandleFunc("PUT /api/settings/{key}", handlers.UpdateSetting(db))
```

```dart
// In app_router.dart:
GoRoute(
  path: '/admin',
  builder: (context, state) => const AdminSettingsPage(),
),
```
